--!strict
--[=[
	SoundGroupTracker: this client's SoundGroups and the place cut (split out of SoundServiceClient). It keeps the volume
	groups (Music / SFX / UI / Ambient), the mix buses nested in them (SoundConstants.BUSES), and the place groups
	(`SFX/Building`, `SFX/Outside`) nested in those, each made on first use; and the outdoor boxes and the listener's
	place that `setPlaces` sets (docs/superpowers/specs/2026-11-04-sound-places.md). A change of listener fades each
	place group to its gain for the new place. `placeFor` is the place a play is in now (SoundFormulas.placeOfPlay
	of its point in the boxes).

	Used by SoundServiceClient (tracks, sliders, the place cut) and SoundVoicePool (a play joins its place's group).

	@class SoundGroupTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundShared = ReplicatedStorage.Shared.Features.Sound
local SoundTypes = require(SoundShared.Data.SoundTypes)
local SoundConstants = require(SoundShared.Data.SoundConstants)
local SoundFormulas = require(SoundShared.Utils.SoundFormulas)

type SoundGroupName = SoundTypes.SoundGroupName
type SoundBusName = SoundTypes.SoundBusName
type SoundPlace = SoundTypes.SoundPlace

local groups: { [string]: SoundGroup? } = {}
-- The mix buses' groups, by bus name, each nested in its volume group (SoundConstants.BUSES).
local busGroups: { [string]: SoundGroup? } = {}
-- The place groups, by "<volume group>/<bus>/<place>", nested in their bus (or volume) group, and each one's running
-- fade.
local placeGroups: { [string]: SoundGroup? } = {}
-- Each place's groups (one per volume group). Kept per place, not in one map by place: iterating a map's literal-typed
-- values widens them to string.
local buildingGroups: { SoundGroup } = {}
local outsideGroups: { SoundGroup } = {}
local placeFades: { [SoundGroup]: Tween? } = {}
-- The outdoor boxes and the local player's place (setPlaces); none = nothing is placed.
local placeBoxes: { SoundTypes.SoundPlaceBox } = {}
local listenerPlace: SoundPlace? = nil

local function groupFor(name: SoundGroupName): SoundGroup
	local existing = groups[name]
	if existing ~= nil then
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = name
	created.Volume = SoundConstants.DEFAULT_GROUP_VOLUMES[name]
	created.Parent = SoundService
	groups[name] = created
	return created
end

-- The group of mix bus `bus` in volume group `name` (made on first use at its trim), or the volume group itself with
-- no bus.
local function busGroupFor(name: SoundGroupName, bus: SoundBusName?): SoundGroup
	local parent = groupFor(name)
	if bus == nil then
		return parent
	end
	local existing = busGroups[bus]
	if existing ~= nil then
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = bus
	created.Volume = SoundFormulas.busGain(SoundConstants.BUSES[bus])
	created.Parent = parent
	busGroups[bus] = created
	return created
end

-- The group a sound of volume group `name` and bus `bus` joins in `place`: its place group nested in the bus group
-- (made on first use, at the listener's gain), or the bus group itself when placeless.
local function placeGroupFor(name: SoundGroupName, bus: SoundBusName?, place: SoundPlace?): SoundGroup
	local parent = busGroupFor(name, bus)
	if place == nil then
		return parent
	end
	local key = `{name}/{bus or ""}/{place}`
	local existing = placeGroups[key]
	if existing ~= nil then
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = place
	created.Volume = SoundFormulas.placeGain(place, listenerPlace)
	created.Parent = parent
	placeGroups[key] = created
	table.insert(if place == "Outside" then outsideGroups else buildingGroups, created)
	return created
end

-- Fades each of `place`'s groups to its gain for the listener's place over `fade` (0: at once).
local function fadePlace(list: { SoundGroup }, place: SoundPlace, fade: number)
	local gain = SoundFormulas.placeGain(place, listenerPlace)
	for _, group in list do
		local running = placeFades[group]
		if running ~= nil then
			placeFades[group] = nil
			running:Cancel()
		end
		if fade <= 0 then
			group.Volume = gain
		else
			local tween = TweenService:Create(group, TweenInfo.new(fade), { Volume = gain })
			placeFades[group] = tween
			tween:Play()
		end
	end
end

-- Where a play at `at` sounds from in the world; nil for a 2D play.
local function pointOf(at: SoundTypes.PlayAt?): Vector3?
	if typeof(at) == "Vector3" then
		return at
	elseif typeof(at) == "Instance" then
		if at:IsA("BasePart") then
			return at.Position
		elseif at:IsA("Attachment") then
			return at.WorldPosition
		end
	end
	return nil
end

-- The place a play of `def` at `at` is in now (nil: placeless, heard everywhere; a pinned sound is in its place).
local function placeFor(def: SoundTypes.SoundDef, at: SoundTypes.PlayAt?): SoundPlace?
	return SoundFormulas.placeOfPlay(def, pointOf(at), placeBoxes)
end

-- Sets the outdoor boxes and the listener's place; a change of listener fades each place group to its gain over
-- `fade` (0: at once).
local function setPlaces(boxes: { SoundTypes.SoundPlaceBox }, listener: SoundPlace?, fade: number?)
	placeBoxes = boxes
	if listener ~= listenerPlace then
		listenerPlace = listener
		fadePlace(buildingGroups, "Building", fade or 0)
		fadePlace(outsideGroups, "Outside", fade or 0)
	end
end

-- The outdoor boxes (setPlaces); none = nothing is placed.
local function boxes(): { SoundTypes.SoundPlaceBox }
	return placeBoxes
end

-- The local player's place (setPlaces); nil while nothing is placed.
local function listener(): SoundPlace?
	return listenerPlace
end

local SoundGroupTracker = {
	groupFor = groupFor,
	busGroupFor = busGroupFor,
	placeGroupFor = placeGroupFor,
	pointOf = pointOf,
	placeFor = placeFor,
	setPlaces = setPlaces,
	boxes = boxes,
	listener = listener,
}

return SoundGroupTracker
