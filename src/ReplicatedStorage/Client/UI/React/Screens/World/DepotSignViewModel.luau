--!strict
--[=[
	DepotSignViewModel: the hub's number-and-picture boards (owner 11-12, kit mock round 2 #2: numbers and pictures,
	not sentences; words for young players):
	- `clock`: CLOCK IN, one punch hole per day up to the locker key (TimecardConstants.KEY_PUNCH), filled for each
	  punch this week, today's open hole glowing, then the key, earned or not.
	- `daily`: TODAY, the job as a picture and a count, how far along it is, and the Credits it pays.
	- `ranks`: RANKS, every rank a numbered step in its lanyard colour, climbing, the player's step marked (the names
	  stay in the close-up rank chart).

	@class DepotSignViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local RankRegistry = require(ReplicatedStorage.Shared.Features.Rank.Data.RankRegistry)
local TimecardConstants = require(ReplicatedStorage.Shared.Features.Timecard.Data.TimecardConstants)
local TimecardRules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)
local WorkOrderRegistry = require(ReplicatedStorage.Shared.Features.WorkOrder.Data.WorkOrderRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)

export type Slot = "punched" | "today" | "empty"
export type ClockView = { title: string, slots: { Slot }, keyEarned: boolean }
export type DailyView = {
	title: string,
	icon: UIAssets.ToonIcon,
	count: string,
	progress: string,
	fill: number,
	done: boolean,
	reward: string,
}
export type Step = { number: string, color: Color3, height: number, you: boolean }
export type RanksView = { title: string, steps: { Step }, you: number }

-- The job's picture by work-order kind.
local JOB_ICON: { [string]: UIAssets.ToonIcon } = {
	piles = "dust",
	cargo = "gleamCrate",
	salvage = "gleamBucket",
	shifts = "stopwatch",
}
-- The lowest step's height as a share of the tallest (the steps climb evenly between).
local LOWEST_STEP = 0.32

local DepotSignViewModel = {}

function DepotSignViewModel.clock(status: TimecardRules.Status): ClockView
	local slots: { Slot } = {}
	for index = 1, TimecardConstants.KEY_PUNCH do
		local slot: Slot = if index <= status.count
			then "punched"
			elseif index == status.count + 1 and status.canPunch then "today"
			else "empty"
		table.insert(slots, slot)
	end
	return { title = "CLOCK IN", slots = slots, keyEarned = status.count >= TimecardConstants.KEY_PUNCH }
end

function DepotSignViewModel.daily(order: WorkOrderRegistry.WorkOrder, work: PlayerDataTypes.WorkOrder): DailyView
	local done = work.claimed or work.progress >= order.target
	local reached = math.clamp(math.floor(work.progress), 0, order.target)
	if done then
		reached = order.target
	end
	return {
		title = "TODAY",
		icon = JOB_ICON[order.kind] or "jobs",
		count = `x{order.target}`,
		progress = `{reached}/{order.target}`,
		fill = reached / math.max(1, order.target),
		done = done,
		reward = `+{WorkOrderRegistry.REWARD_CREDITS}`,
	}
end

function DepotSignViewModel.ranks(xp: number?): RanksView
	local current = RankFormulas.levelFor(math.max(xp or 0, 0)).level
	local levels = RankRegistry.all()
	local steps: { Step } = {}
	for index, level in levels do
		local share = if #levels > 1 then (index - 1) / (#levels - 1) else 1
		table.insert(steps, {
			number = tostring(index),
			color = level.lanyard,
			height = LOWEST_STEP + (1 - LOWEST_STEP) * share,
			you = level.level == current,
		})
	end
	return { title = "RANKS", steps = steps, you = current }
end

return DepotSignViewModel
