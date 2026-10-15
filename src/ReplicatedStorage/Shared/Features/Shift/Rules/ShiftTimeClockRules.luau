--!strict
--[=[
	ShiftTimeClockRules: whether a crew member may use the truck's paperwork (the time clock's Clock out, the overtime
	sheet's Start overtime). Both hang on the inside of the box's front wall; a player may use one only with empty
	hands (so it never competes with Bank cargo, which needs something carried) and only standing in front of it
	inside the box: `offset` is the player's root in the item's own space (-Z out of the wall), checked against
	ShiftConstants.PAPERWORK_REACH. Pure: the client hides the prompt by it, the server refuses the trigger by it.

	@class ShiftTimeClockRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

export type Refusal = "carrying" | "out-of-reach"

local ShiftTimeClockRules = {}

function ShiftTimeClockRules.canUse(offset: Vector3, carrying: boolean): (boolean, Refusal?)
	if carrying then
		return false, "carrying"
	end
	local reach = ShiftConstants.PAPERWORK_REACH
	if
		offset.Z > 0
		or offset.Z < -reach.depth
		or math.abs(offset.X) > reach.halfWidth
		or offset.Y < -reach.below
		or offset.Y > reach.above
	then
		return false, "out-of-reach"
	end
	return true, nil
end

return ShiftTimeClockRules
