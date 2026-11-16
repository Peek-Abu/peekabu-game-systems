--!strict
--[=[
	TrainingTargetUtils: what the training guide points at (split out of TrainingTrailSystem). `targetNow` reads the
	Training map (its parts' role and stop attributes), the run's spawned piles, cargo and hiding furniture (by their
	tags) and what the local player carries, and returns the floor point the trail leads to with what it saw of the
	player (TrainingGuideRules.Situation: the stop's door open, the treasure carried, hidden at the hide stop). It only
	reads the world; TrainingTrailSystem keeps the guide's state and passes in whether the player has hidden at this
	stop and the last stop escaped at.

	@class TrainingTargetUtils
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingGuideRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingGuideRules)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local HideStore = require(ReplicatedStorage.Client.Features.Hide.State.HideStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

local function rootOf(): BasePart?
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function mapOf(): Model?
	for _, tagged in CollectionService:GetTagged(TrainingConstants.MAP_TAG) do
		if tagged:IsA("Model") then
			return tagged
		end
	end
	return nil
end

-- The map's parts with `role` (and `stopNumber` when given).
local function marked(map: Model, role: string, stopNumber: number?): { BasePart }
	local found: { BasePart } = {}
	for _, part in map:GetDescendants() do
		if
			part:IsA("BasePart")
			and part:GetAttribute(TrainingConstants.ROLE_ATTRIBUTE) == role
			and (stopNumber == nil or part:GetAttribute(TrainingConstants.STOP_ATTRIBUTE) == stopNumber)
		then
			table.insert(found, part)
		end
	end
	return found
end

local function inside(box: BasePart, position: Vector3): boolean
	local localPoint = box.CFrame:PointToObjectSpace(position)
	local half = box.Size / 2
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y + 4
		and math.abs(localPoint.Z) <= half.Z
end

local function inZone(map: Model, stopNumber: number, position: Vector3): boolean
	for _, zone in marked(map, "zone", stopNumber) do
		if inside(zone, position) then
			return true
		end
	end
	return false
end

local function nearest(parts: { BasePart }, from: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, part in parts do
		local distance = (part.Position - from).Magnitude
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	return best
end

-- The run's live parts tagged `tag` inside the stop's zone.
local function liveInZone(map: Model, stopNumber: number, tag: string): { BasePart }
	local found: { BasePart } = {}
	for _, tagged in CollectionService:GetTagged(tag) do
		if tagged:IsA("BasePart") and tagged:IsDescendantOf(Workspace) and inZone(map, stopNumber, tagged.Position) then
			table.insert(found, tagged)
		end
	end
	return found
end

-- A treasure is salvage cargo (its kind is the Carry kind attribute; the cargo id is a number).
local function isTreasureKind(kind: unknown): boolean
	local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
	return def ~= nil and def.category == "salvage"
end

local function isTreasure(part: BasePart): boolean
	return isTreasureKind(part:GetAttribute(CarryConstants.KIND_ATTRIBUTE))
end

-- Whether a treasure sits in one of the local player's item slots (picked up: pocketed, its world part gone).
local function pocketedTreasure(): boolean
	local player = Players.LocalPlayer
	if player == nil then
		return false
	end
	local entry = StateSyncClientStore.publicPlayers()[StateSyncConstants.publicEntryKey(player.UserId)]
	if entry == nil then
		return false
	end
	for _, fields in CargoConstants.SLOT_FIELDS do
		if isTreasureKind(entry[fields.kind]) then
			return true
		end
	end
	return false
end

-- The stop's treasure, carried or not: the cargo the local player holds, else the one in the zone.
local function treasureOf(map: Model, stopNumber: number): (BasePart?, boolean)
	local player = Players.LocalPlayer
	local userId = if player ~= nil then player.UserId else 0
	for _, tagged in CollectionService:GetTagged(CarryConstants.TAG) do
		if
			tagged:IsA("BasePart")
			and isTreasure(tagged)
			and tagged:GetAttribute(CarryConstants.CARRIED_BY_ATTRIBUTE) == userId
		then
			return tagged, true
		end
	end
	-- Picked up (owner 11-12: grabbing the mug is not loading it): the guide points at the truck until it is loaded.
	if pocketedTreasure() then
		return nil, true
	end
	local loose: { BasePart } = {}
	for _, part in liveInZone(map, stopNumber, CarryConstants.TAG) do
		if isTreasure(part) then
			table.insert(loose, part)
		end
	end
	local root = rootOf()
	return if root ~= nil then nearest(loose, root.Position) else loose[1], false
end

local function doorOpen(map: Model, stopNumber: number): boolean
	for _, door in marked(map, "door", stopNumber) do
		if door:GetAttribute("TrainingOpen") == true then
			return true
		end
	end
	return false
end

local function truckBed(map: Model): BasePart?
	local truck = map:FindFirstChild("Truck")
	local bed = if truck ~= nil then truck:FindFirstChild("TruckBed") else nil
	return if bed ~= nil and bed:IsA("BasePart") then bed else nil
end

-- What the guide points at now, as a floor point (nil = nothing), and what it sees of the player. `hiddenHere`: the
-- player has hidden at this stop already (the returned situation's `hidden` is its new value); `clearStop`: the last
-- stop the player escaped at.
local function targetNow(
	map: Model,
	stopNumber: number,
	from: Vector3,
	hiddenHere: boolean,
	clearStop: number?
): (Vector3?, TrainingGuideRules.Situation)
	local treasure, carrying = nil, false
	if TrainingConstants.STOPS[stopNumber] ~= nil and TrainingConstants.STOPS[stopNumber].id == "treasure" then
		treasure, carrying = treasureOf(map, stopNumber)
	end
	if HideStore.hidden() ~= nil and TrainingGuideRules.tone(stopNumber) == "danger" then
		hiddenHere = true
	end
	local situation: TrainingGuideRules.Situation = {
		stopDone = doorOpen(map, stopNumber) or clearStop == stopNumber,
		carrying = carrying,
		hidden = hiddenHere,
	}
	local kind = TrainingGuideRules.target(stopNumber, situation)
	local part: BasePart? = nil
	if kind == "pile" then
		part = nearest(liveInZone(map, stopNumber, VacuumConstants.PILE_TAG), from)
	elseif kind == "treasure" then
		part = treasure
	elseif kind == "truck" then
		part = truckBed(map)
	elseif kind == "desk" then
		part = nearest(liveInZone(map, stopNumber, HideConstants.FURNITURE_TAG), from)
	elseif kind == "next" then
		part = marked(map, "stop", stopNumber + 1)[1]
	end
	if part == nil then
		return nil, situation
	end
	-- The floor under the target (its bottom face; a desk's front edge is where you crouch in).
	local floor = part.Position - Vector3.new(0, part.Size.Y / 2, 0)
	return floor, situation
end

local TrainingTargetUtils = {
	rootOf = rootOf,
	mapOf = mapOf,
	marked = marked,
	inside = inside,
	nearest = nearest,
	isTreasureKind = isTreasureKind,
	doorOpen = doorOpen,
	truckBed = truckBed,
	targetNow = targetNow,
}

return TrainingTargetUtils
