--!strict
--[=[
	OfficeServiceServer: the Harlow & Finch office (Cleanup Crew spec Â§6.2 "Office", Â§6.5 "Reset"). At start
	it validates the authored layout (OfficeLayoutRules; a broken layout is a boot error) and builds the
	authored core at start; seeded modular geometry each shift (OfficeBuildSystem), then its night decor (OfficeDecorSystem), at OfficeConstants.ORIGIN, far from the origin where M4's depot
	goes. Each shift `beginShift` rolls the spawns (OfficeSpawnUtils, re-rolling with the next seed, up to
	ROLL_ATTEMPTS times, if OfficeSpawnRules finds a broken guarantee; then it proceeds with the last roll) and places them in ONE per-shift folder owned by ONE Janitor:
	piles (Vacuum), items (Cargo), hidden items under piles (revealed when the pile is cleared; the pile is marked
	CargoConstants.BURIED_ATTRIBUTE, its glint), and desk / locker contents (Cargo). Every valuable spawns with the
	appraisal the roll gave it, fully grimy (the loot loop). `reset` destroys that folder and forgets the shift.

	M2: Harlow's route, rest point and the safe loading bay (`route`, `restPoint`, `safeZone`).

	Spec-exempt shell (Instances, signals); the decisions are the specced OfficeLayoutRules, OfficeLayoutUtils,
	OfficeSpawnUtils and OfficeSpawnRules.

	@class OfficeServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local CargoAppraisalFormulas = require(ReplicatedStorage.Shared.Features.Cargo.Utils.CargoAppraisalFormulas)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeLayoutConstants = require(OfficeServer.Data.OfficeLayoutConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutRules = require(OfficeServer.Rules.OfficeLayoutRules)
local OfficeSpawnRules = require(OfficeServer.Rules.OfficeSpawnRules)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeLayoutGenerationUtils = require(OfficeServer.Utils.OfficeLayoutGenerationUtils)
local OfficeLoadingBayUtils = require(OfficeServer.Utils.OfficeLoadingBayUtils)
local OfficeFurniturePlacementUtils = require(OfficeServer.Utils.OfficeFurniturePlacementUtils)
local OfficeSpawnUtils = require(OfficeServer.Utils.OfficeSpawnUtils)
local OfficeBuildSystem = require(OfficeServer.Systems.OfficeBuildSystem)
local OfficeDecorSystem = require(OfficeServer.Systems.OfficeDecorSystem)
local OfficeSearchedDressingSystem = require(OfficeServer.Systems.OfficeSearchedDressingSystem)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

type Marker = OfficeTypes.Marker

local LAYOUT = OfficeFurniturePlacementUtils.normalize(OfficeLayoutConstants.LAYOUT)
local depths = OfficeLayoutUtils.depths(LAYOUT)

local log = Logger.new("OfficeServiceServer")

local markerById: { [string]: Marker } = {}
for _, marker in LAYOUT.markers do
	markerById[marker.id] = marker
end

local built: OfficeBuildSystem.Built? = nil
local shiftJanitor = Janitor.new()
local shiftFolder: Folder? = nil
local dressing = OfficeSearchedDressingSystem.new()
-- pile â†’ the item hidden under it, for this shift.
local hidden: { [BasePart]: BasePart } = {}
local lastPlan: OfficeTypes.SpawnPlan? = nil
local stoppers: { () -> () } = {}

-- The floor point under a marker, in the world.
local function floorAt(marker: Marker): CFrame
	return OfficeConstants.ORIGIN * CFrame.new(marker.x, 0, marker.z)
end

-- Where an item stands: furniture tops for surface markers, the floor otherwise.
local function spotFrame(marker: Marker): CFrame
	local top = OfficeLayoutUtils.surfaceTopY(marker.kind)
	if top ~= nil then
		local current = built
		if current ~= nil then
			for _, part in current.model:GetDescendants() do
				if
					part:IsA("BasePart")
					and (
						part:GetAttribute("OfficeMarkerId") == marker.id
						or part:GetAttribute("OfficeDeskMarker") == marker.id
					)
				then
					local support = part:GetAttribute("ArtSupportSurfaceY")
					if type(support) == "number" then
						return part.CFrame * CFrame.new(0, support - part.Size.Y / 2, 0)
					end
				end
			end
		end
		return OfficeConstants.ORIGIN * CFrame.new(marker.x, top, marker.z)
	end
	return floorAt(marker)
end

-- Harlow's route in the world, in walking order, and his rest point (M2).
local routePoints: { Vector3 } = {}
for _, id in LAYOUT.route do
	local marker = markerById[id]
	if marker ~= nil then
		table.insert(routePoints, floorAt(marker).Position)
	end
end
local restMarker = markerById[LAYOUT.rest]

local function rebuild(seed: number)
	local layout = OfficeFurniturePlacementUtils.normalize(
		OfficeLayoutGenerationUtils.generate(OfficeLayoutConstants.LAYOUT, seed)
	)
	local ok, errors = OfficeLayoutRules.validate(layout)
	assert(ok, `generated office layout is invalid: {table.concat(errors, "; ")}`)
	local capacity, reason = OfficeLayoutRules.checkCapacity(layout)
	assert(capacity, reason or "generated layout capacity")
	local routeOk, routeReason = OfficeLayoutRules.checkRoute(layout)
	assert(routeOk, routeReason or "generated layout route")
	LAYOUT = layout
	depths = OfficeLayoutUtils.depths(layout)
	table.clear(markerById)
	for _, marker in layout.markers do
		markerById[marker.id] = marker
	end
	table.clear(routePoints)
	for _, id in layout.route do
		local marker = markerById[id]
		if marker ~= nil then
			table.insert(routePoints, floorAt(marker).Position)
		end
	end
	restMarker = markerById[layout.rest]
	local old = built
	if old ~= nil then
		old.model:Destroy()
	end
	local current = OfficeBuildSystem.build(layout, OfficeConstants.ORIGIN)
	current.model:SetAttribute("LayoutSeed", seed)
	built = current
	OfficeDecorSystem.build(layout, OfficeConstants.ORIGIN, current.model)
end

-- A rolled valuable as it spawns (fully grimy, unappraised); nil for trash.
local function fresh(roll: CargoTypes.AppraisalRoll?): CargoTypes.Appraisal?
	return if roll ~= nil then CargoAppraisalFormulas.fresh(roll) else nil
end

local function rollPlan(options: { seed: number, variant: string, quota: number }): OfficeTypes.SpawnPlan
	local rollOptions: OfficeTypes.RollOptions = {
		quota = options.quota,
		variant = options.variant,
		piles = OfficeConstants.PILES,
		valuables = OfficeConstants.VALUABLES,
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
	route: (self: OfficeServiceServer) -> { Vector3 },
	restPoint: (self: OfficeServiceServer) -> Vector3,
	safeZone: (self: OfficeServiceServer) -> (Vector3, Vector3),
	whereIs: (self: OfficeServiceServer, position: Vector3) -> (string?, number?, number?),
	truckBed: (self: OfficeServiceServer) -> BasePart?,
	overtimeSheet: (self: OfficeServiceServer) -> BasePart?,
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
		local routeOk, routeReason = OfficeLayoutRules.checkRoute(LAYOUT)
		assert(routeOk, `office layout has no usable patrol route: {routeReason or "?"}`)
		local current = OfficeBuildSystem.build(LAYOUT, OfficeConstants.ORIGIN)
		built = current
		-- The office at night (exit signs, blue monitors, the elevator, ambience emitters), once.
		OfficeDecorSystem.build(LAYOUT, OfficeConstants.ORIGIN, current.model)
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
		-- Searched desks and lockers stay visibly open until the shift ends.
		local dressed = CargoServiceServer.searched:Connect(function(part)
			if part.Name == "Desk" then
				dressing.apply(part, "desk")
			elseif part.Name == "Locker" then
				dressing.apply(part, "locker")
			end
		end)
		table.insert(stoppers, function()
			dressed:Disconnect()
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
		assert(built ~= nil, "OfficeServiceServer:beginShift before start")
		rebuild(options.seed)
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
					hidden[pile] = CargoServiceServer:spawnItem(
						hides,
						floor,
						folder,
						{ hidden = true, appraisal = fresh(pilePlan.appraisal) }
					)
					pile:SetAttribute(CargoConstants.BURIED_ATTRIBUTE, true)
				end
			end
		end
		for _, itemPlan in plan.items do
			local marker = markerById[itemPlan.marker]
			if marker ~= nil then
				CargoServiceServer:spawnItem(
					itemPlan.kind,
					spotFrame(marker),
					folder,
					{ appraisal = fresh(itemPlan.appraisal) }
				)
			end
		end
		for _, search in plan.searchables do
			local part: BasePart? = current.searchables[search.marker]
			if part ~= nil then
				CargoServiceServer:stockSearchable(part, search.kind, fresh(search.appraisal))
			end
		end
		lastPlan = plan
		log:info(`shift spawns: {#plan.piles} piles, {#plan.items} items, worth {plan.value} clean`)
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
		dressing.clear()
	end,

	--[=[
		Where the `index`-th crew member appears: in the truck's bed, facing out of its open back and down the ramp
		(OfficeLoadingBayUtils.arrivalFrame). Shift arrivals, the shift start and crew respawns all land here.
	]=]
	spawnCFrame = function(_self, index)
		return OfficeConstants.ORIGIN * OfficeLoadingBayUtils.arrivalFrame(LAYOUT.truck, index)
	end,

	container = function(_self)
		return shiftFolder
	end,

	--[=[
		Harlow's patrol points in the world, in walking order (a loop).
	]=]
	route = function(_self)
		return table.clone(routePoints)
	end,

	--[=[
		Where Harlow takes his break (the break room).
	]=]
	restPoint = function(_self)
		if restMarker == nil then
			error("OfficeServiceServer:restPoint: the layout has no rest marker")
		end
		return floorAt(restMarker).Position
	end,

	--[=[
		The loading bay in the world: its min and max corners, floor to wall top (Harlow's safe zone).
	]=]
	safeZone = function(_self)
		local start = OfficeLayoutUtils.room(LAYOUT, LAYOUT.startRoom)
		if start == nil then
			error("OfficeServiceServer:safeZone: the layout has no start room")
		end
		local min, max = OfficeLayoutUtils.bounds(start, OfficeConstants.WALL_HEIGHT)
		return OfficeConstants.ORIGIN:PointToWorldSpace(min), OfficeConstants.ORIGIN:PointToWorldSpace(max)
	end,

	--[=[
		The room a world position stands in: its name, how many rooms from the loading bay, and its camera number (its
		index in the layout). Nothing outside the office.
	]=]
	whereIs = function(_self, position)
		local localPoint = OfficeConstants.ORIGIN:PointToObjectSpace(position)
		local room, index = OfficeLayoutUtils.roomAt(LAYOUT, localPoint.X, localPoint.Z)
		if room == nil then
			return nil, nil, nil
		end
		return room.name, depths[room.id], index
	end,

	--[=[
		The truck bed in the loading bay (Cargo's Load zone), once the office is built.
	]=]
	truckBed = function(_self)
		local current = built
		return if current ~= nil then current.bed else nil
	end,

	--[=[
		The overtime sheet beside the time clock (Shift's Start overtime prompt), once the office is built.
	]=]
	overtimeSheet = function(_self)
		local current = built
		return if current ~= nil then current.overtime else nil
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
			value = if plan ~= nil then plan.value else 0,
			greed = if plan ~= nil and plan.greed ~= nil then `{plan.greed.kind} @ {plan.greed.marker}` else nil,
			hiddenUnderPiles = hiddenCount,
			routePoints = #routePoints,
		}
	end,
}

return OfficeServiceServer
