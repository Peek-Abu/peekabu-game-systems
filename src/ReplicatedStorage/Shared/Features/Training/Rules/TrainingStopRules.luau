--!strict
--[=[
	TrainingStopRules: the training run's progress through its stops (TrainingConstants.STOPS), one step at a time.
	A stop with its own goal (its piles cleared, its treasure loaded) is done when `complete` reports that goal; the
	next stop can only be entered once it is. A walk stop is done by walking into the next stop. Walking into the last
	stop finishes the run. A door opens once its stop is done. The player is never moved backwards: a catch sends
	them to the start of `state.stop`.

	@class TrainingStopRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)

export type State = {
	stop: number,
	done: { [number]: boolean },
	finished: boolean,
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
