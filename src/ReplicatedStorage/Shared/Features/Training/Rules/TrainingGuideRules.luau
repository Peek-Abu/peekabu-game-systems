--!strict
--[=[
	TrainingGuideRules: what the training guide shows at each stop (tutorial v3): what the floor trail and the bobbing
	arrow point at, whether the stop is calm (gold) or dangerous (red, the hide stop), the goal bar's card, and Pippa's
	line and pose. Plus the catch beat's phase at a time since the grab.

	A stop's guide moves on to the next stop once the stop is done (its door is open, or the player got away at the
	escape stop), and at the treasure stop to the truck while the player carries the treasure. At the escape stop it
	points at the glowing desk (one way to get away; running is the other), shows nothing while the player hides, and
	once he has gone Pippa cheers "He's gone! Go now!" and the arrows come back toward the next stop.

	@class TrainingGuideRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)

-- What the guide points at: the stop's Gloom pile, its treasure, the truck bed, the next stop's start, a hiding
-- desk, or nothing.
export type Target = "pile" | "treasure" | "truck" | "next" | "desk" | "none"

export type Tone = "calm" | "danger"

-- What the client knows about the player at their stop.
export type Situation = {
	-- The stop's own goal is met (its door stands open; at the escape stop, the player got away).
	stopDone: boolean,
	-- The player is carrying the stop's treasure.
	carrying: boolean,
	-- The player has hidden at this stop.
	hidden: boolean,
}

export type CatchPhase = "grab" | "splat" | "card" | "dark" | "back" | "done"

local STOPS = TrainingConstants.STOPS

local function idOf(stop: number): string?
	local def = STOPS[stop]
	return if def ~= nil then def.id else nil
end

local TrainingGuideRules = {}

--[=[
	What the guide points at for a player at `stop`.
]=]
function TrainingGuideRules.target(stop: number, situation: Situation): Target
	local id = idOf(stop)
	if id == nil or id == "done" then
		return "none"
	elseif situation.stopDone then
		return "next"
	elseif id == "hide" then
		return if situation.hidden then "none" else "desk"
	elseif id == "dust" then
		return "pile"
	elseif id == "treasure" then
		return if situation.carrying then "truck" else "treasure"
	end
	return "next"
end

--[=[
	The stop's tone: the hide stop is the dangerous one (red trail, red goal bar, red screen).
]=]
function TrainingGuideRules.tone(stop: number): Tone
	return if idOf(stop) == "hide" then "danger" else "calm"
end

--[=[
	The floor trail's tone: the stop's tone, except gold again once the player got away at the escape stop (the way on
	is safe now).
]=]
function TrainingGuideRules.trailTone(stop: number, situation: Situation): Tone
	if situation.stopDone then
		return "calm"
	end
	return TrainingGuideRules.tone(stop)
end

--[=[
	The goal bar's card for `stop`; nil outside the stops.
]=]
function TrainingGuideRules.goal(stop: number): TrainingConstants.GoalCard?
	local id = idOf(stop)
	return if id ~= nil then TrainingConstants.GOALS[id] else nil
end

--[=[
	Pippa's line and pose for a player at `stop`; nil outside the stops.
]=]
function TrainingGuideRules.coach(stop: number, situation: Situation): TrainingConstants.CoachLine?
	local id = idOf(stop)
	if id == nil then
		return nil
	end
	local lines = TrainingConstants.COACH
	if id == "done" then
		return lines.done
	elseif id == "treasure" and situation.carrying and not situation.stopDone then
		return lines.carrying
	elseif id == "hide" and situation.stopDone then
		return lines.clear
	elseif id == "hide" and situation.hidden then
		return lines.hidden
	elseif situation.stopDone then
		return lines.open
	end
	return lines[id]
end

--[=[
	Where the catch beat is, `elapsed` seconds after the grab (TrainingConstants.CATCH_BEAT); "done" before it starts
	or after it ends.
]=]
function TrainingGuideRules.catchPhase(elapsed: number): CatchPhase
	local beat = TrainingConstants.CATCH_BEAT
	if elapsed < 0 or elapsed >= beat.done then
		return "done"
	elseif elapsed >= beat.back then
		return "back"
	elseif elapsed >= beat.dark then
		return "dark"
	elseif elapsed >= beat.card then
		return "card"
	elseif elapsed >= beat.splat then
		return "splat"
	end
	return "grab"
end

--[=[
	Whether the player really used their crew move since the step began: an effect is running, or the ready time moved
	on from the one the step began with (`startReady`) into the future (a cooldown that was already running does not
	count). Server times.
]=]
function TrainingGuideRules.powerUsed(startReady: number, ready: number, serverNow: number, active: string?): boolean
	return active ~= nil or (ready ~= startReady and ready > serverNow)
end

--[=[
	Whether the player has run long enough to pass the run step (seconds sprinted, added up).
]=]
function TrainingGuideRules.ranEnough(sprintSeconds: number): boolean
	return sprintSeconds >= TrainingConstants.RUN_SECONDS
end

return TrainingGuideRules
