--!strict
--[=[
	OfficeShiftSpawnSystem: one shift's spawns, from roll to world. `roll` rolls the plan (OfficeSpawnUtils with the
	map's spawn numbers, re-rolling with the next seed up to ROLL_ATTEMPTS times while OfficeSpawnRules finds a broken
	guarantee, then using the last roll); `place` puts its piles (Vacuum), hidden items under piles (Cargo, the pile
	marked CargoConstants.BURIED_ATTRIBUTE), items and desk / locker contents into the shift folder; `placeOvertime`
	places an overtime batch. Every valuable spawns `fresh` (fully grimy, unappraised). `spotFrame` is where an item
	stands (an art furniture top, else the layout's top, else the floor). `watch` reveals a hidden item when its pile
	is cleared and keeps searched desks and lockers dressed open. Split out of OfficeServiceServer, which owns the
	shift's state and passes it in. Logs under OfficeServiceServer's tag, as before the split.

	@class OfficeShiftSpawnSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local CargoAppraisalFormulas = require(ReplicatedStorage.Shared.Features.Cargo.Utils.CargoAppraisalFormulas)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeSpawnRules = require(OfficeServer.Rules.OfficeSpawnRules)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeSiteUtils = require(OfficeServer.Utils.OfficeSiteUtils)
local OfficeSpawnUtils = require(OfficeServer.Utils.OfficeSpawnUtils)
local OfficeSurfaceUtils = require(OfficeServer.Utils.OfficeSurfaceUtils)
local OfficeBuildSystem = require(OfficeServer.Systems.OfficeBuildSystem)
local OfficeSearchedDressingSystem = require(OfficeServer.Systems.OfficeSearchedDressingSystem)
local OfficeBuildPaceTracker = require(OfficeServer.State.OfficeBuildPaceTracker)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

type Marker = OfficeTypes.Marker

-- OfficeServiceServer's tag: these lines logged from it before the split.
local log = Logger.new("OfficeServiceServer")

local floorAt = OfficeSiteUtils.floorAt

local OfficeShiftSpawnSystem = {}

-- Where an item stands: furniture tops for surface markers, the floor otherwise. `current` is the office standing.
local function spotFrame(current: OfficeBuildSystem.Built?, marker: Marker): CFrame
	local top = OfficeLayoutUtils.surfaceTopFor(marker)
	if top ~= nil then
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
					local onArt = OfficeSurfaceUtils.surfaceOnPart(part.CFrame, part.Size, support)
					if onArt ~= nil then
						return onArt
					end
				end
			end
		end
		return OfficeConstants.ORIGIN * CFrame.new(marker.x, top, marker.z)
	end
	return floorAt(marker)
end

-- A rolled valuable as it spawns (fully grimy, unappraised); nil for trash.
local function fresh(roll: CargoTypes.AppraisalRoll?): CargoTypes.Appraisal?
	return if roll ~= nil then CargoAppraisalFormulas.fresh(roll) else nil
end

OfficeShiftSpawnSystem.spotFrame = spotFrame
OfficeShiftSpawnSystem.fresh = fresh

-- Rolls one shift's spawn plan on `layout`.
function OfficeShiftSpawnSystem.roll(
	layout: OfficeTypes.Layout,
	options: { seed: number, variant: string, quota: number, map: ShiftTypes.MapId }
): OfficeTypes.SpawnPlan
	-- The map's own spawn numbers: the School rolls more mess and richer valuables than the Office.
	local byMap = OfficeConstants.SPAWN_BY_MAP
	local spawn = if options.map == "school" then byMap.school else byMap.office
	local rollOptions: OfficeTypes.RollOptions = {
		quota = options.quota,
		variant = options.variant,
		dirtyRooms = spawn.dirtyRooms,
		pilesPerRoom = spawn.pilesPerRoom,
		valuables = spawn.valuables,
		valueScale = spawn.valueScale,
		topUpMax = spawn.topUpMax,
	}
	local plan: OfficeTypes.SpawnPlan
	for attempt = 0, OfficeConstants.ROLL_ATTEMPTS - 1 do
		local seed = options.seed + attempt
		plan = OfficeSpawnUtils.roll(layout, rollOptions, Random.new(seed))
		local ok, reason = OfficeSpawnRules.check(plan, layout, options.quota)
		if ok then
			return plan
		end
		log:warn(`spawn roll {seed} missed a guarantee: {reason or "?"}`)
	end
	log:warn(`no spawn roll from seed {options.seed} met the guarantees; using the last one`)
	return plan
end

--[=[
	Places `plan` in `folder` on `current` (the office just rebuilt): piles (each hidden item recorded in `hidden`
	under its pile), items, then desk and locker contents. Markers are looked up in `markerById`.
]=]
function OfficeShiftSpawnSystem.place(
	plan: OfficeTypes.SpawnPlan,
	current: OfficeBuildSystem.Built,
	folder: Folder,
	markerById: { [string]: Marker },
	hidden: { [BasePart]: BasePart }
)
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
		OfficeBuildPaceTracker.step()
	end
	for _, itemPlan in plan.items do
		local marker = markerById[itemPlan.marker]
		if marker ~= nil then
			CargoServiceServer:spawnItem(
				itemPlan.kind,
				spotFrame(current, marker),
				folder,
				{ appraisal = fresh(itemPlan.appraisal) }
			)
		end
		OfficeBuildPaceTracker.step()
	end
	for _, search in plan.searchables do
		local part: BasePart? = current.searchables[search.marker]
		if part ~= nil then
			CargoServiceServer:stockSearchable(part, search.kind, fresh(search.appraisal))
		end
	end
end

-- Places an overtime `batch` in `folder` (each item `overtime = true`); returns how many spawned.
function OfficeShiftSpawnSystem.placeOvertime(
	batch: { OfficeTypes.ItemPlan },
	current: OfficeBuildSystem.Built?,
	folder: Folder,
	markerById: { [string]: Marker }
): number
	local spawned = 0
	for _, itemPlan in batch do
		local marker = markerById[itemPlan.marker]
		if marker ~= nil then
			CargoServiceServer:spawnItem(
				itemPlan.kind,
				spotFrame(current, marker),
				folder,
				{ appraisal = fresh(itemPlan.appraisal), overtime = true }
			)
			spawned += 1
		end
	end
	return spawned
end

--[=[
	Reveals the item hidden under a pile (`hidden`) when the pile is cleared, and dresses searched desks and lockers
	open (`dressing`). Each disconnect is appended to `stoppers`.
]=]
function OfficeShiftSpawnSystem.watch(
	hidden: { [BasePart]: BasePart },
	dressing: OfficeSearchedDressingSystem.Controller,
	stoppers: { () -> () }
)
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
end

return OfficeShiftSpawnSystem
