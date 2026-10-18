--!strict
--[=[
	ShiftNoticeUtils: what the crew is told when the pacing moves (Cleanup Crew spec §3 step 5, §4 "Pacing", §7, and the
	opt-in overtime of docs/cleanup-crew-lore.md "Contract sequence"): the quota met, with the company's notice
	(COMPANY_THRESHOLD) and the choice (clock out, or start overtime at the truck); the end of the break; the overtime
	warning once a crew member starts it; overtime itself; and each pressure tier ("Site activity is picking up…"). Clocking
	out (ShiftClockOutRules): who punched and how many are on the truck, and the truck's countdown.
	Since 2026-10-16 they speak of "site activity", never of the Manager, so any anomaly on site can share them. The two big moments are a rubber stamp (QUOTA MET, OVERTIME) followed by sticky notes with the
	detail; the rest are sticky notes (spec §6.1, §7 "sticky-note toasts, rubber-stamp announcements"). Pure: the
	service sends what this returns.

	@class ShiftNoticeUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)

type ToastRequest = ToastTypes.ToastRequest

-- Morrow & Morrow's announcement when the clearance quota is met (docs/cleanup-crew-lore.md).
local COMPANY_THRESHOLD =
	"Clearance threshold reached. Optional recovery remains available. Extended-site coverage is not guaranteed."

-- "m:ss", seconds rounded up.
local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function stamp(text: string): ToastRequest
	return { text = text, style = ShiftConstants.TOAST_STAMP, duration = ShiftConstants.STAMP_SECONDS }
end

local function note(text: string): ToastRequest
	return { text = text, style = ShiftConstants.TOAST_STICKY, duration = ShiftConstants.NOTICE_SECONDS }
end

local ShiftNoticeUtils = {}

--[=[
	The toasts for the step from `before` to `after` (both running; otherwise none), in the order they happen. The
	tier note waits out the break and the warning, and gives way to the break's end (the tier still advances; their
	own notices speak then).
]=]
function ShiftNoticeUtils.notices(before: ShiftTypes.ShiftState, after: ShiftTypes.ShiftState): { ToastRequest }
	local list: { ToastRequest } = {}
	if before.phase ~= "running" or after.phase ~= "running" then
		return list
	end
	local multiplier = ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER
	if after.quotaMet and not before.quotaMet then
		table.insert(list, stamp("CONTRACT MET"))
		table.insert(list, note(COMPANY_THRESHOLD))
		table.insert(
			list,
			note(
				`Site activity has settled for now. Clock out at the truck to leave, or start overtime there: assets ×{multiplier}, more activity.`
			)
		)
	end
	local breakOver = before.stage == "break" and after.stage == "normal"
	if breakOver then
		table.insert(list, note("Site activity is picking up again. Overtime is still your call."))
	end
	if after.stage == "warning" and before.stage ~= "warning" then
		table.insert(
			list,
			note(
				`Overtime in {clock(ShiftConstants.WARNING_SECONDS)}: assets ×{multiplier}. Bank your cargo and regroup.`
			)
		)
	end
	if after.stage == "overtime" and before.stage ~= "overtime" then
		table.insert(list, stamp("OVERTIME"))
		table.insert(list, note(`Assets ×{multiplier} until the clock runs out. Site activity is heavier now.`))
	elseif after.tier > before.tier and after.stage ~= "break" and after.stage ~= "warning" and not breakOver then
		table.insert(list, note("Site activity is picking up…"))
	end
	return list
end

--[=[
	A crew member punched their card: who, and how many of the crew still in are now on the truck (`count` of `total`).
]=]
function ShiftNoticeUtils.punched(name: string, count: number, total: number): ToastRequest
	return note(`{name} clocked out: {count}/{total} on the truck.`)
end

--[=[
	Half the crew has clocked out: the truck's countdown starts (ShiftClockOutRules). Nobody is left without pay.
]=]
function ShiftNoticeUtils.truckLeaving(): { ToastRequest }
	local seconds = ShiftConstants.TRUCK_LEAVES_SECONDS
	return {
		stamp(`TRUCK LEAVES IN {seconds}`),
		note(
			`Half the crew clocked out. The truck leaves in {clock(seconds)}: clock out to ride along. Everyone gets paid.`
		),
	}
end

return ShiftNoticeUtils
