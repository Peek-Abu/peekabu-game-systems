--!strict
--[=[
	OccupantCatchUtils: what a finished catch does next, once the Shift has spent the player's life. A catch that leaves
	a life is a hit (spec 2026-10-20 §1): not killed but knocked down (Death's knockdown), so there is no back-at time
	to publish, no incident report, no Rehired notice. The catch that spends the last life kills and keeps the player
	down for the shift (no back-at time, no rehire). The crew gets no text either way (owner P1 2026-11-14: the HUD's
	lives and the catch itself tell it). Pure.

	@class OccupantCatchUtils
]=]

export type AfterCatch = {
	-- Killed (the last life's catch) rather than knocked down.
	kill: boolean,
	-- The `caughtUntil` to publish; nil when the player is not on a respawn timer (a hit, or out for the shift).
	publishBack: number?,
	rehire: boolean,
}

local OccupantCatchUtils = {}

--[=[
	The aftermath of a catch: `knockedOut` (this was the player's last life).
]=]
function OccupantCatchUtils.afterCatch(knockedOut: boolean): AfterCatch
	if knockedOut then
		return { kill = true, publishBack = nil, rehire = false }
	end
	return { kill = false, publishBack = nil, rehire = false }
end

export type Feedback = {
	-- The first-catch tip.
	tip: boolean,
}

--[=[
	Who is told about a catch: on a shift, only the caught player (their first-catch tip, once ever); on a training
	run, nobody here, because training sends the player its one line itself (TrainingRunSystem).
]=]
function OccupantCatchUtils.feedback(training: boolean): Feedback
	return { tip = not training }
end

return OccupantCatchUtils
