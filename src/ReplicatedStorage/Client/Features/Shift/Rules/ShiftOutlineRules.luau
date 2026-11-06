--!strict
--[=[
	ShiftOutlineRules: the shift's through-the-walls outlines (ShiftOutlineSystem). Pure.

	- The way back: the truck is outlined through walls once it is time to go: the quota is met, the truck's clock-out
	  countdown runs, the overtime warning or overtime is on, or the shift is in its last LAST_SECONDS.
	- Teammates: each other crew member is outlined through walls, faded in with distance: none within NEAR studs
	  (no clutter beside you), strongest from FAR studs on.

	@class ShiftOutlineRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

-- The fields read here (a ShiftSnapshot has them all).
export type View = {
	phase: ShiftTypes.ShiftPhase,
	sub: ShiftTypes.ShiftSub,
	stage: ShiftTypes.ShiftStage,
	quotaMet: boolean,
	endsAt: number?,
}

local ShiftOutlineRules = {}

ShiftOutlineRules.LAST_SECONDS = 60
ShiftOutlineRules.NEAR = 12
ShiftOutlineRules.FAR = 40
-- The teammate outline's transparency just past NEAR and from FAR on.
local FAINT = 0.8
local STRONG = 0.3

function ShiftOutlineRules.truckShown(view: View?, now: number): boolean
	if view == nil or view.phase ~= "running" then
		return false
	end
	if view.quotaMet or view.sub == "clockout" or view.stage == "warning" or view.stage == "overtime" then
		return true
	end
	local endsAt = view.endsAt
	return endsAt ~= nil and endsAt - now <= ShiftOutlineRules.LAST_SECONDS
end

--[=[
	The outline's transparency for a teammate `distance` studs away; nil: no outline.
]=]
function ShiftOutlineRules.teammateTransparency(distance: number): number?
	if distance < ShiftOutlineRules.NEAR then
		return nil
	end
	local t = math.clamp((distance - ShiftOutlineRules.NEAR) / (ShiftOutlineRules.FAR - ShiftOutlineRules.NEAR), 0, 1)
	return FAINT + (STRONG - FAINT) * t
end

return ShiftOutlineRules
