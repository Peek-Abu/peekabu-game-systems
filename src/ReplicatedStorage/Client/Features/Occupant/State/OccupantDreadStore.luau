--!strict
--[=[
	OccupantDreadStore: the local player's dread stage as the UI sees it (OccupantTypes.DreadStage: nothing; he is near;
	he sees you or hunts; he chases you; a crewmate near you is chased). OccupantDreadSystem writes it only when the stage
	changes (never per frame), so a widget can read it reactively: the phone's helper button lets HIDE win over the other
	prompts while there is any danger (ShiftHelperViewModel). Nothing here is sent back.

	@class OccupantDreadStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)

local NONE: OccupantTypes.DreadStage = "none"
local stage = Charm.atom(NONE)
local danger = Charm.computed(function(): boolean
	return stage() ~= "none"
end)

local OccupantDreadStore = {
	stage = stage,
	-- Any dread at all: he is near, or hunting, or chasing you or a crewmate by you.
	danger = danger,
}

function OccupantDreadStore.setStage(next: OccupantTypes.DreadStage)
	stage(next)
end

function OccupantDreadStore.clear()
	stage(NONE)
end

return OccupantDreadStore
