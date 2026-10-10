--!strict
--[=[
	OfficeServiceServer: the Harlow & Finch office (Cleanup Crew spec §6.2 "Office", §6.5 "Reset"). At start
	it validates the authored layout (OfficeLayoutRules; a broken layout is a boot error) and builds the
	static graybox once (OfficeBuildSystem) at OfficeConstants.ORIGIN, far from the origin where M4's depot
	goes. Each shift `beginShift` rolls the spawns (OfficeSpawnUtils, re-rolling with the next seed, up to
	ROLL_ATTEMPTS times, if OfficeSpawnRules finds a broken guarantee; then it proceeds with the last roll) and places them in ONE per-shift folder owned by ONE Janitor:
	piles (Vacuum), items (Cargo), hidden items under piles (revealed when the pile is cleared), and desk /
	locker contents (Cargo). `reset` destroys that folder and forgets the shift.

	Spec-exempt shell (Instances, signals); the decisions are the specced OfficeLayoutRules, OfficeLayoutUtils,
	OfficeSpawnUtils and OfficeSpawnRules.

	@class OfficeServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeLayoutConstants = require(OfficeServer.Data.OfficeLayoutConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutRules = require(OfficeServer.Rules.OfficeLayoutRules)
local OfficeSpawnRules = require(OfficeServer.Rules.OfficeSpawnRules)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeSpawnUtils = require(OfficeServer.Utils.OfficeSpawnUtils)
local OfficeBuildSystem = require(OfficeServer.Systems.OfficeBuildSystem)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

type Marker = OfficeTypes.Marker

local LAYOUT = OfficeLayoutConstants.LAYOUT

local log = Logger.new("OfficeServiceServer")

local markerById: { [string]: Marker } = {}
for _, marker in LAYOUT.markers do
	markerById[marker.id] = marker
end
local spawnMarkers = OfficeLayoutUtils.markersOf(LAYOUT, "spawn")

local built: OfficeBuildSystem.Built? = nil
local shiftJanitor = Janitor.new()
local shiftFolder: Folder? = nil
-- pile → the item hidden under it, for this shift.
local hidden: { [BasePart]: BasePart } = {}
local lastPlan: OfficeTypes.SpawnPlan? = nil
local stoppers: { () -> () } = {}

-- The floor point under a marker, in the world.
local function floorAt(marker: Marker): CFrame
	return OfficeConstants.ORIGIN * CFrame.new(marker.x, 0, marker.z)
end

local function rollPlan(options: { seed: number, variant: string, quota: number }): OfficeTypes.SpawnPlan
	local rollOptions: OfficeTypes.RollOptions = {
		quota = options.quota,
		variant = options.variant,
		piles = OfficeConstants.PILES,
		salvage = OfficeConstants.SALVAGE,
	}
	local plan: OfficeTypes.SpawnPlan
	for attempt = 0, OfficeConstants.ROLL_ATTEMPTS - 1 do
		local seed = options.seed + attempt
		plan = OfficeSpawnUtils.roll(LAYOUT, rollOptions, Random.new(seed))
		local ok, reason = OfficeSpawnRules.check(plan, LAYOUT, options.quota)
		if ok then
			return plan
		end
		log:warn(`spawn roll {seed} missed a guarantee: {reason or "?"}`)
	end
	log:warn(`no spawn roll from seed {options.seed} met the guarantees; using the last one`)
	return plan
end

export type OfficeServiceServer = {
	dependencies: { string },
	start: (self: OfficeServiceServer) -> (),
	stop: (self: OfficeServiceServer) -> (),
	getState: (self: OfficeServiceServer) -> { [string]: any },
	beginShift: (
		self: OfficeServiceServer,
		options: { seed: number, variant: string, quota: number }
	) -> OfficeTypes.SpawnPlan,
	reset: (self: OfficeServiceServer) -> (),
	spawnCFrame: (self: OfficeServiceServer, index: number) -> CFrame,
	container: (self: OfficeServiceServer) -> Folder?,
}

local OfficeServiceServer: OfficeServiceServer = {
	dependencies = { "VacuumServiceServer", "CargoServiceServer" },

	--[=[
		Validates and builds the office, and reveals hidden items as their piles are cleared.
	]=]
	start = function(_self)
		local ok, errors = OfficeLayoutRules.validate(LAYOUT)
		assert(ok, `office layout is invalid:\n{table.concat(errors, "\n")}`)
		local capacityOk, reason = OfficeLayoutRules.checkCapacity(LAYOUT)
		assert(capacityOk, `office layout cannot hold a shift: {reason or "?"}`)
		built = OfficeBuildSystem.build(LAYOUT, OfficeConstants.ORIGIN)
		local cleared = VacuumServiceServer.pileCleared:Connect(function(pile)
			local item: BasePart? = hidden[pile]
			hidden[pile] = nil
			if item ~= nil and item.Parent ~= nil then
				CargoServiceServer:reveal(item)
			end
		end)
		table.insert(stoppers, function()
			cleared:Disconnect()
		end)
	end,

	stop = function(self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		self:reset()
		local current = built
		if current ~= nil then
			current.model:Destroy()
			built = nil
		end
	end,

	--[=[
		Resets, then rolls and places one shift's spawns. Returns the plan placed.
	]=]
	beginShift = function(self, options)
		self:reset()
		local current = built
		assert(current ~= nil, "OfficeServiceServer:beginShift before start")
		local plan = rollPlan(options)
		local folder = Instance.new("Folder")
		folder.Name = OfficeConstants.SHIFT_FOLDER_NAME
		folder.Parent = current.model
		shiftJanitor:Add(folder, "Destroy")
		shiftFolder = folder
		CargoServiceServer:useContainer(folder)

		for _, pilePlan in plan.piles do
			local marker = markerById[pilePlan.marker]
			if marker ~= nil then
				local floor = floorAt(marker)
				local pile = VacuumServiceServer:spawnPile(pilePlan.kind, floor, folder)
				local hides = pilePlan.hides
				if hides ~= nil then
					hidden[pile] = CargoServiceServer:spawnItem(hides, floor, folder, { hidden = true })
				end
			end
		end
		for _, itemPlan in plan.items do
			local marker = markerById[itemPlan.marker]
			if marker ~= nil then
				CargoServiceServer:spawnItem(itemPlan.kind, floorAt(marker), folder)
			end
		end
		for _, search in plan.searchables do
			local part: BasePart? = current.searchables[search.marker]
			if part ~= nil then
				CargoServiceServer:stockSearchable(part, search.kind)
			end
		end
		lastPlan = plan
		log:info(`shift spawns: {#plan.piles} piles, {#plan.items} items, {plan.trashValue} trash`)
		return plan
	end,

	--[=[
		Destroys everything the current shift spawned (the one folder) and forgets it. The caller (Shift) resets
		Cargo and Vacuum alongside it.
	]=]
	reset = function(_self)
		shiftJanitor:Cleanup()
		CargoServiceServer:useContainer(nil)
		shiftFolder = nil
		table.clear(hidden)
		lastPlan = nil
	end,

	--[=[
		Where the `index`-th crew member appears in the loading bay (wrapping over the spawn markers).
	]=]
	spawnCFrame = function(_self, index)
		local marker = spawnMarkers[(math.max(index, 1) - 1) % #spawnMarkers + 1]
		return OfficeConstants.ORIGIN * CFrame.new(marker.x, OfficeConstants.SPAWN_HEIGHT, marker.z)
	end,

	container = function(_self)
		return shiftFolder
	end,

	getState = function(_self)
		local plan = lastPlan
		local hiddenCount = 0
		for _ in hidden do
			hiddenCount += 1
		end
		return {
			built = built ~= nil,
			shift = shiftFolder ~= nil,
			piles = if plan ~= nil then #plan.piles else 0,
			items = if plan ~= nil then #plan.items else 0,
			trashValue = if plan ~= nil then plan.trashValue else 0,
			greed = if plan ~= nil and plan.greed ~= nil then `{plan.greed.kind} @ {plan.greed.marker}` else nil,
			hiddenUnderPiles = hiddenCount,
		}
	end,
}

return OfficeServiceServer
