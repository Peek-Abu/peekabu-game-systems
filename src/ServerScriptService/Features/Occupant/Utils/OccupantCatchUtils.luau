--!strict
--[=[
	OccupantCatchUtils: what a finished catch does next, once the Shift has spent the player's life. A catch that leaves
	a life is a hit (spec 2026-10-20 §1): not killed but knocked down (Death's knockdown), so there is no back-at time
	to publish, no incident report, no Rehired notice, and the crew is told they got caught. The catch that spends the
	last life kills and keeps the player down for the shift (no back-at time, the crew is told they are out, no
	rehire). Pure.

	@class OccupantCatchUtils
]=]

export type AfterCatch = {
	-- Killed (the last life's catch) rather than knocked down.
	kill: boolean,
	-- The `caughtUntil` to publish; nil when the player is not on a respawn timer (a hit, or out for the shift).
	publishBack: number?,
	toast: "hit" | "out",
	rehire: boolean,
}

local OccupantCatchUtils = {}

--[=[
	The aftermath of a catch: `knockedOut` (this was the player's last life).
]=]
function OccupantCatchUtils.afterCatch(knockedOut: boolean): AfterCatch
	if knockedOut then
		return { kill = true, publishBack = nil, toast = "out", rehire = false }
	end
	return { kill = false, publishBack = nil, toast = "hit", rehire = false }
end

return OccupantCatchUtils
