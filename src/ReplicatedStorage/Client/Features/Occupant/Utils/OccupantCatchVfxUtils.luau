--!strict
--[=[
	OccupantCatchVfxUtils: when a player's public fields say a catch just threw them (OccupantCatchVfxSystem).

	A normal catch publishes a `caughtUntil` deadline; the last-life catch (Gloom lives' knock-out) publishes none, only
	`knockedOut`. Either turning on, from off at the last look, is a throw; a field that stays on (a republish) is not.

	@class OccupantCatchVfxUtils
]=]

local OccupantCatchVfxUtils = {}

--[=[
	True when a throw just happened: the deadline appeared, or the player just turned knocked out.
]=]
function OccupantCatchVfxUtils.thrown(
	wasCaught: boolean,
	isCaught: boolean,
	wasKnockedOut: boolean,
	isKnockedOut: boolean
): boolean
	return (isCaught and not wasCaught) or (isKnockedOut and not wasKnockedOut)
end

return OccupantCatchVfxUtils
