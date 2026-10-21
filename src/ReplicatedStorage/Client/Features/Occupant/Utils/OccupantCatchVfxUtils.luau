--!strict
--[=[
	OccupantCatchVfxUtils: when a player's public fields say a catch just threw them (OccupantCatchVfxSystem).

	Catches 1 and 2 knock the player down (the server marks the character with the Knockdown attribute); the 3rd
	catch knocks them out (public `knockedOut`). No catch publishes a `caughtUntil` deadline today, but one that
	did would throw too. Any of the three turning on, from off at the last look, is a throw; one that stays on (a
	republish) is not.

	@class OccupantCatchVfxUtils
]=]

local OccupantCatchVfxUtils = {}

--[=[
	True when a throw just happened: a deadline appeared, the player just turned knocked out, or their character
	just went down (a knockdown).
]=]
function OccupantCatchVfxUtils.thrown(
	wasCaught: boolean,
	isCaught: boolean,
	wasKnockedOut: boolean,
	isKnockedOut: boolean,
	wasDown: boolean,
	isDown: boolean
): boolean
	return (isCaught and not wasCaught) or (isKnockedOut and not wasKnockedOut) or (isDown and not wasDown)
end

return OccupantCatchVfxUtils
