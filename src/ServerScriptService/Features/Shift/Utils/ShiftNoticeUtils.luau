--!strict
--[=[
	ShiftNoticeUtils: what the crew is told when the pacing moves (spec §3 step 5, §4 "Pacing", §7): the quota
	met and Harlow's break; "Overtime in 0:30, salvage ×1.5"; overtime itself; and each pressure tier ("You
	hear Harlow pacing faster…"). Plain toasts in M2; the stamp and sticky-note styles are M3. Pure: the
	service sends what this returns.

	@class ShiftNoticeUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)

type ToastRequest = ToastTypes.ToastRequest

-- "m:ss", seconds rounded up.
local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local ShiftNoticeUtils = {}

--[=[
	The toasts for the step from `before` to `after` (both running; otherwise none), in the order they happen. The tier note waits out the break and the warning
	(the tier still advances; their own notices speak then).
]=]
function ShiftNoticeUtils.notices(before: ShiftTypes.ShiftState, after: ShiftTypes.ShiftState): { ToastRequest }
	local list: { ToastRequest } = {}
	if before.phase ~= "running" or after.phase ~= "running" then
		return list
	end
	local duration = ShiftConstants.NOTICE_SECONDS
	local multiplier = ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER
	if after.quotaMet and not before.quotaMet then
		table.insert(list, {
			text = `QUOTA MET. Mr. Harlow is on his break for {clock(ShiftConstants.BREAK_SECONDS)}: regroup and bank.`,
			duration = duration,
		})
	end
	if after.stage == "warning" and before.stage ~= "warning" then
		table.insert(list, {
			text = `Overtime in {clock(ShiftConstants.WARNING_SECONDS)}, salvage ×{multiplier}`,
			duration = duration,
		})
	end
	if after.stage == "overtime" and before.stage ~= "overtime" then
		table.insert(list, {
			text = `OVERTIME. Salvage ×{multiplier} until the clock runs out. Harlow is back, and faster.`,
			duration = duration,
		})
	elseif after.tier > before.tier and after.stage ~= "break" and after.stage ~= "warning" then
		table.insert(list, { text = "You hear Harlow pacing faster…", duration = duration })
	end
	return list
end

return ShiftNoticeUtils
