--!strict
--[=[
	AbilityRules: whether a player may use their ability now (`canUse`), and whether a running Potted Plant ends
	(`plantEnds`). Pure. Spec: docs/superpowers/specs/2026-10-29-employee-abilities-design.md.

	@class AbilityRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityConstants = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityConstants)
local AbilityTypes = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityTypes)

export type UseInput = {
	-- A shift is running, and the player plays in it.
	running: boolean,
	participant: boolean,
	alive: boolean,
	-- In the Manager's grab (a catch in progress).
	caught: boolean,
	hidden: boolean,
	-- Server time now, and when the ability is ready.
	now: number,
	readyAt: number,
	def: AbilityTypes.AbilityDef?,
	-- Standing on the floor; something in the hands (pocketed items are not).
	grounded: boolean,
	holding: boolean,
	-- Spot It! has a treasure to show.
	hasTarget: boolean,
}

export type PlantInput = {
	now: number,
	startedAt: number,
	maxSeconds: number,
	-- Studs across the floor the root has moved since the plant began.
	moved: number,
	grounded: boolean,
	-- Doing anything else: sprinting, vacuuming, hiding, holding something, an emote.
	acting: boolean,
	alive: boolean,
	caught: boolean,
	-- The client asked to stop (its move or action input).
	cancelled: boolean,
}

local AbilityRules = {}

--[=[
	Whether the use is allowed; else the first reason it is not.
]=]
function AbilityRules.canUse(input: UseInput): (boolean, AbilityTypes.Reason?)
	local def = input.def
	if def == nil then
		return false, "noAbility"
	elseif not input.running then
		return false, "notRunning"
	elseif not input.participant then
		return false, "notPlaying"
	elseif not input.alive then
		return false, "dead"
	elseif input.caught then
		return false, "caught"
	elseif input.hidden then
		return false, "hidden"
	elseif input.now < input.readyAt then
		return false, "cooldown"
	elseif def.id == "pottedPlant" and not input.grounded then
		return false, "airborne"
	elseif def.id == "pottedPlant" and input.holding then
		return false, "holding"
	elseif def.id == "spotIt" and not input.hasTarget then
		return false, "nothing"
	end
	return true, nil
end

--[=[
	Why a running plant ends now, or nil while it holds.
]=]
function AbilityRules.plantEnds(input: PlantInput): AbilityTypes.EndReason?
	if not input.alive then
		return "dead"
	elseif input.caught then
		return "caught"
	elseif input.cancelled then
		return "cancelled"
	elseif input.moved > AbilityConstants.PLANT_MOVE_TOLERANCE then
		return "moved"
	elseif not input.grounded then
		return "jumped"
	elseif input.acting then
		return "acted"
	elseif input.now - input.startedAt >= input.maxSeconds then
		return "timeout"
	end
	return nil
end

return AbilityRules
