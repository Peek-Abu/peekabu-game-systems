--!strict
--[=[
	OccupantCatchUtils: what a finished catch does next, once the Shift has spent the player's life. A catch that leaves
	lives back is the usual one (the report's back-at time is published, the crew is told "caught", the player is owed the
	Rehired notice); the catch that spends the last life keeps the player down for the shift (no back-at time, the crew is
	told they are out, no rehire). Pure.

	@class OccupantCatchUtils
]=]

export type AfterCatch = {
	-- The `caughtUntil` to publish; nil when the player is not coming back.
	publishBack: number?,
	toast: "caught" | "out",
	rehire: boolean,
}

local OccupantCatchUtils = {}

--[=[
	The aftermath of a catch: `knockedOut` (this was the player's last life) and `backAt` (when the report says they are
	back).
]=]
function OccupantCatchUtils.afterCatch(knockedOut: boolean, backAt: number): AfterCatch
	if knockedOut then
		return { publishBack = nil, toast = "out", rehire = false }
	end
	return { publishBack = backAt, toast = "caught", rehire = true }
end

return OccupantCatchUtils
