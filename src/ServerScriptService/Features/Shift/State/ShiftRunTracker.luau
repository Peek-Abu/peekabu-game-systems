--!strict
--[=[
	ShiftRunTracker: what the shift service remembers about the run between calls, as one record (ShiftRunSystem
	moves it; the service's own methods read and write it): the run's review once it has one, whether a reset waits for
	Round's results, whether the clock-out has ended Round's run (the tick repeats `endShift` until Round leaves
	running), whose coffee ran first and for how many seconds of the shift, and whether this server's run is a training
	run (kept across runs, cleared by nobody but `setTraining`). Plain fields: the callers own the rules.

	Split out of ShiftServiceServer (its file-level state), so ShiftRunSystem can share it.

	@class ShiftRunTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

export type ShiftRunTracker = {
	-- The current shift's review, from the clock out or the timeout until the next shift starts.
	results: ShiftTypes.ShiftResults?,
	-- Set by a mid-run reset: Round's results then finish the reset instead of opening the review.
	resetPending: boolean,
	-- Set once the clock-out has ended Round's run: the tick repeats `endShift` until Round leaves running.
	endingRun: boolean,
	-- Coffee for the crew this shift: whose coffee ran first (nil = none) and how many seconds of the shift it ran.
	-- Cleared with the run.
	coffeeBy: string?,
	coffeeSeconds: number,
	-- A training run: the pressure tier never rises, and a catch's crew feedback is training's own.
	training: boolean,
}

local ShiftRunTracker = {}

function ShiftRunTracker.new(): ShiftRunTracker
	return {
		results = nil,
		resetPending = false,
		endingRun = false,
		coffeeBy = nil,
		coffeeSeconds = 0,
		training = false,
	}
end

return ShiftRunTracker
