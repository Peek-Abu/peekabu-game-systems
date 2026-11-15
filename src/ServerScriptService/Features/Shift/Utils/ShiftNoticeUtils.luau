--!strict
--[=[
	ShiftNoticeUtils: what the crew is told when the pacing moves (Cleanup Crew spec §3 step 5, §4 "Pacing", §7). Only
	the big moments, each one rubber stamp: GOAL DONE! when the quota is met, OVERTIME when it starts, and the truck's
	countdown once half the crew has clocked out (ShiftClockOutRules). Everything else rides the HUD, the sounds and
	the world (owner P1 2026-11-14: "this is a game, not a newspaper"): no notes for the break, the overtime warning,
	the pressure tiers or a crew member's punch. Pure: the service sends what this returns.

	@class ShiftNoticeUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)

type ToastRequest = ToastTypes.ToastRequest

local function stamp(text: string): ToastRequest
	return { text = text, style = ShiftConstants.TOAST_STAMP, duration = ShiftConstants.STAMP_SECONDS }
end

local ShiftNoticeUtils = {}

--[=[
	The stamps for the step from `before` to `after` (both running; otherwise none), in the order they happen.
]=]
function ShiftNoticeUtils.notices(before: ShiftTypes.ShiftState, after: ShiftTypes.ShiftState): { ToastRequest }
	local list: { ToastRequest } = {}
	if before.phase ~= "running" or after.phase ~= "running" then
		return list
	end
	if after.quotaMet and not before.quotaMet then
		table.insert(list, stamp("GOAL DONE!"))
	end
	if after.stage == "overtime" and before.stage ~= "overtime" then
		table.insert(list, stamp("OVERTIME"))
	end
	return list
end

--[=[
	Half the crew has clocked out: the truck's countdown starts (ShiftClockOutRules).
]=]
function ShiftNoticeUtils.truckLeaving(): ToastRequest
	return stamp(`TRUCK LEAVES IN {ShiftConstants.TRUCK_LEAVES_SECONDS}`)
end

return ShiftNoticeUtils
