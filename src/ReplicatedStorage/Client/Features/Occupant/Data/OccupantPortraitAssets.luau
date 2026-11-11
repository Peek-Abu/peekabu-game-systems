--!strict
--[=[
	OccupantPortraitAssets: the portrait a monster kind (OccupantKindRegistry) shows on a run's cards, by kit icon name
	(the image ids themselves live in UIAssets.toonIcons). Each kind has a slot per mood: `calm` (the trip card's tip,
	the MOST CAUGHT award) and `hunt` (the review's Crew caught card). Harlow's are his manager renders. Bramble's are
	its own named slots, PENDING "" until rendered and uploaded; while a slot is "" (and for an unknown kind) `portrait`
	is NEUTRAL, a monster-neutral kit icon, never another kind's face.

	@class OccupantPortraitAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantKindRegistry = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantKindRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)

export type Mood = "calm" | "hunt"

type Slots = { calm: UIAssets.ToonIcon, hunt: UIAssets.ToonIcon }

local SLOTS: { [OccupantKindRegistry.KindId]: Slots } = {
	harlow = { calm = "managerCalm", hunt = "managerHunt" },
	bramble = { calm = "brambleCalm", hunt = "brambleHunt" },
}

-- The stand-in for an empty slot: the flashlight render (a kid looking into the dark), about no one monster.
local NEUTRAL: UIAssets.ToonIcon = "flashlight"

local OccupantPortraitAssets = {
	NEUTRAL = NEUTRAL,
}

--[=[
	Kind `kind`'s slot for `mood` (filled or PENDING), or nil for an unknown kind.
]=]
function OccupantPortraitAssets.slot(kind: string, mood: Mood): UIAssets.ToonIcon?
	local id: OccupantKindRegistry.KindId? = OccupantKindRegistry.parse(kind)
	local slots = if id ~= nil then SLOTS[id] else nil
	if slots == nil then
		return nil
	end
	return if mood == "calm" then slots.calm else slots.hunt
end

--[=[
	The icon to draw for kind `kind` in `mood`: its slot once filled, else NEUTRAL.
]=]
function OccupantPortraitAssets.portrait(kind: string, mood: Mood): UIAssets.ToonIcon
	local slot: UIAssets.ToonIcon? = OccupantPortraitAssets.slot(kind, mood)
	if slot ~= nil and UIAssets.toonIcons[slot] ~= "" then
		return slot
	end
	return NEUTRAL
end

return table.freeze(OccupantPortraitAssets)
