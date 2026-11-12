--!strict
--[=[
	TrainingStepRules: the first stop's steps, strictly one after another (owner 11-12: "tasks should be guaranteed to do
	before next steps"): suck up the Gloom, then run, then use the power (an employee without a power skips it). The
	stop is done, and its door opens, only once every step is (TrainingRunSystem). Nothing counts before its own step:
	sprinting or the power during the Gloom step, or the power during the run step, are ignored, and a step's progress
	starts at zero when it begins. The Gloom cannot be cleared early either: it needs the vacuum out, which is the
	hotbar tour's first tip.

	- run: RUN_SECONDS of sprinting, added up while the step is on.
	- power: a real use (the ready time moves on from the one the step began with, into the future; a cooldown already
	  running does not count) or a press of the power button (`pressed`: a power that cannot fire here, such as Spot It
	  with no treasure near, still teaches the button).

	Pure: the server senses the player (TrainingRunSystem) and publishes the current step (TrainingConstants.STEP_ENTRY)
	for the client's tips.

	@class TrainingStepRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)

export type Step = "gloom" | "run" | "power"

export type State = {
	steps: { Step },
	index: number,
	-- Seconds sprinted during the run step.
	sprinted: number,
	-- The power's ready time when the power step began.
	startReady: number,
}

-- One tick of what the server sees: seconds since the last tick, whether the player is sprinting, their power's
-- ready time (server time; 0 = ready), whether they pressed the power button since the last tick, and the server time.
export type Facts = {
	dt: number,
	sprinting: boolean,
	readyAt: number,
	pressed: boolean,
	now: number,
}

local TrainingStepRules = {}

--[=[
	The steps from the start: the Gloom, the run, and the power when the employee has one.
]=]
function TrainingStepRules.new(hasPower: boolean): State
	local steps: { Step } = { "gloom", "run" }
	if hasPower then
		table.insert(steps, "power")
	end
	return { steps = steps, index = 1, sprinted = 0, startReady = 0 }
end

--[=[
	The step on now; nil once every step is done.
]=]
function TrainingStepRules.current(state: State): Step?
	return state.steps[state.index]
end

function TrainingStepRules.done(state: State): boolean
	return state.index > #state.steps
end

-- Moves on to the next step, which starts from zero (`readyAt` is the power's ready time now).
local function advance(state: State, readyAt: number)
	state.index += 1
	state.sprinted = 0
	state.startReady = readyAt
end

--[=[
	The stop's Gloom was all sucked up. True when that finished the Gloom step (it was the step on).
]=]
function TrainingStepRules.cleared(state: State): boolean
	if TrainingStepRules.current(state) ~= "gloom" then
		return false
	end
	advance(state, 0)
	return true
end

--[=[
	One tick: the run and power steps' progress. True when a step finished.
]=]
function TrainingStepRules.tick(state: State, facts: Facts): boolean
	local step = TrainingStepRules.current(state)
	if step == "run" then
		if facts.sprinting then
			state.sprinted += facts.dt
		end
		if state.sprinted >= TrainingConstants.RUN_SECONDS then
			advance(state, facts.readyAt)
			return true
		end
	elseif step == "power" then
		local used = facts.readyAt ~= state.startReady and facts.readyAt > facts.now
		if used or facts.pressed then
			advance(state, facts.readyAt)
			return true
		end
	end
	return false
end

return TrainingStepRules
