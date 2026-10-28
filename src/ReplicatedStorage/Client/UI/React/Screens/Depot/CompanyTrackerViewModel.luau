--!strict
--[=[
	CompanyTrackerViewModel: the Today tracker (CompanyWorkOrderTracker), the player's two daily goals kept on screen.
	`where` says where it shows: in the hub (with no other hub screen or the clipboard up) and in a running shift, while
	pinned (pinned by default; × unpins it for the session). `lines` is what it says: the Timecard line (a call to punch
	while today is free; in a shift that is done at the hub), the Daily Work Order and its progress, and under it the
	reward, or once today's order is paid, the time to tomorrow's. Pure.

	@class CompanyTrackerViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local TimecardConstants = require(ReplicatedStorage.Shared.Features.Timecard.Data.TimecardConstants)
local TimecardRules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)
local WorkOrderRegistry = require(ReplicatedStorage.Shared.Features.WorkOrder.Data.WorkOrderRegistry)

export type Where = "hub" | "shift"

export type WhereInput = {
	pinned: boolean,
	clipboardOpen: boolean,
	inHub: boolean,
	-- Another hub screen is up (a scene, the travel card).
	hubBusy: boolean,
	-- A running shift the player is crew in, not clocking out, caught or hidden away.
	inShift: boolean,
}

export type Lines = {
	timecard: string,
	timecardDue: boolean,
	order: string,
	progress: number,
	target: number,
	claimed: boolean,
	footer: string,
}

local DAY = 86400

local CompanyTrackerViewModel = {}

function CompanyTrackerViewModel.where(input: WhereInput): Where?
	if not input.pinned or input.clipboardOpen then
		return nil
	end
	if input.inHub then
		return if input.hubBusy then nil else "hub"
	end
	return if input.inShift then "shift" else nil
end

local function timecardLine(where: Where, status: TimecardRules.Status): string
	if status.canPunch then
		return if where == "hub" then "PUNCH YOUR TIMECARD!" else "PUNCH IN AT THE HUB!"
	end
	if status.complete then
		return `TIMECARD FULL! {status.count} / {TimecardConstants.PUNCHES_TO_FILL}`
	end
	return `TIMECARD: {status.count} / {TimecardConstants.PUNCHES_TO_FILL} DAYS`
end

--[=[
	The tracker's lines for `work` (already rolled to `now`) and today's `order`.
]=]
function CompanyTrackerViewModel.lines(
	where: Where,
	status: TimecardRules.Status,
	work: PlayerDataTypes.WorkOrder,
	order: WorkOrderRegistry.WorkOrder,
	now: number
): Lines
	local left = math.max(0, math.ceil(DAY - (now % DAY)))
	return {
		timecard = timecardLine(where, status),
		timecardDue = status.canPunch,
		order = if work.claimed then "ALL DONE TODAY!" else order.label,
		progress = work.progress,
		target = order.target,
		claimed = work.claimed,
		footer = if work.claimed
			then `NEW ORDER IN {left // 3600}h {(left // 60) % 60}m`
			else `+{WorkOrderRegistry.REWARD_CREDITS} CREDITS`,
	}
end

return CompanyTrackerViewModel
