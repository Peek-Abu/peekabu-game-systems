--!strict
--[=[
	TrainingStopRules: the training run's progress through its stops (TrainingConstants.STOPS), one step at a time.
	A stop with its own goal (its piles cleared, its treasure loaded) is done when `complete` reports that goal; the
	next stop can only be entered once it is. A walk stop is done by walking into the next stop. Walking into the last
	stop finishes the run. A door opens once its stop is done. The player is never moved backwards: a catch sends
	them to the start of `state.stop`. The escape stop (goal "escape") is done once the player got away from Mr. Harlow
	(`escapeStep`, from what the server senses every poll).

	@class TrainingStopRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)

export type State = {
	stop: number,
	done: { [number]: boolean },
	finished: boolean,
}

-- The escape stop's running count.
export type Escape = {
	-- He came within ESCAPE.near or chased the player at this stop.
	threatened: boolean,
	-- How long the player has been safe without a break (seconds).
	safeFor: number,
	-- How long the player has been at this stop (seconds).
	waited: number,
}

-- What the server senses at a poll.
export type Sense = {
	-- He is within ESCAPE.near studs of the player.
	near: boolean,
	-- He is chasing (or searching for) this player.
	chasing: boolean,
	-- The player is in a hiding spot.
	hidden: boolean,
	-- He has a clear line of sight to the player.
	seen: boolean,
	-- He is at least ESCAPE.far studs away.
	far: boolean,
}

local STOPS = TrainingConstants.STOPS

local TrainingStopRules = {}

--[=[
	A run at its first stop.
]=]
function TrainingStopRules.new(): State
	return { stop = 1, done = {}, finished = false }
end

function TrainingStopRules.isDone(state: State, stop: number): boolean
	return state.done[stop] == true
end

--[=[
	Stop `stop`'s own goal was met. True when that finished the stop (it is the current stop, or the next one once the
	current is done; the goal is that stop's goal; it was not done yet).
]=]
function TrainingStopRules.complete(state: State, stop: number, goal: TrainingConstants.Goal): boolean
	local def = STOPS[stop]
	if def == nil or def.goal ~= goal or state.done[stop] then
		return false
	end
	-- The next stop's goal counts early only once this stop is done (its door is open).
	local ahead = stop == state.stop + 1 and state.done[state.stop] == true
	if stop ~= state.stop and not ahead then
		return false
	end
	state.done[stop] = true
	return true
end

--[=[
	The player walked into stop `stop`'s zone. True when that moved them on (it is the next stop, and the stop before
	is done or is a walk stop, which this finishes). Entering the last stop finishes the run.
]=]
function TrainingStopRules.enter(state: State, stop: number): boolean
	if state.finished or stop ~= state.stop + 1 or STOPS[stop] == nil then
		return false
	end
	local before = STOPS[state.stop]
	if before.goal == "walk" then
		state.done[state.stop] = true
	elseif not state.done[state.stop] then
		return false
	end
	state.stop = stop
	if STOPS[stop].goal == "finish" then
		state.done[stop] = true
		state.finished = true
	end
	return true
end

--[=[
	A fresh escape count (the player just reached the escape stop, or was caught and sent back to it).
]=]
function TrainingStopRules.newEscape(): Escape
	return { threatened = false, safeFor = 0, waited = 0 }
end

--[=[
	Adds `deltaTime` seconds with `sense` to the escape count. True once the player got away: Mr. Harlow came for them
	and they then stayed safe (he is not chasing them, not near, and they are hidden, out of his sight, or far ahead)
	for ESCAPE.seconds without a break; or he never came within ESCAPE.timeout seconds.
]=]
function TrainingStopRules.escapeStep(escape: Escape, deltaTime: number, sense: Sense): boolean
	local rules = TrainingConstants.ESCAPE
	escape.waited += deltaTime
	if sense.chasing or sense.near then
		escape.threatened = true
	end
	local safe = not sense.chasing and not sense.near and (sense.hidden or not sense.seen or sense.far)
	if safe and escape.threatened then
		escape.safeFor += deltaTime
	else
		escape.safeFor = 0
	end
	if escape.threatened then
		return escape.safeFor >= rules.seconds
	end
	return escape.waited >= rules.timeout
end

--[=[
	The stops whose doors stand open (their stop is done), lowest first.
]=]
function TrainingStopRules.openDoors(state: State): { number }
	local open = {}
	for stop = 1, #STOPS do
		if state.done[stop] then
			table.insert(open, stop)
		end
	end
	return open
end

return TrainingStopRules
