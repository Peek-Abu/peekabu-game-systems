--!strict
--[=[
	ShiftNightTracker: the Night Shift run's record, kept outside the shift's per-run clearing (ShiftRunSystem's
	`clearRun`/`clearShift` never touch it), so it lasts from night to night: the run's mode, the night number, tonight's
	goal, the week report's bonus after a survived week, the coats each crew member ended the last night with, every
	night's result, and how the run ended. A quick run keeps only its mode. The decisions are ShiftNightRules'.

	A run starts at the first night's preparation (`needsStart`: no run yet, or the last one is over); Next night moves
	it on (`nextNight`); each night's results settle it once per shift (`settle`); Clock out, a firing or a wipe ends it
	(`finish`).

	@class ShiftNightTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftNightFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftNightFormulas)
local ShiftNightRules = require(script.Parent.Parent.Rules.ShiftNightRules)

type RunMode = ShiftTypes.RunMode
type RunOver = ShiftTypes.RunOver

-- One finished night: its number, its goal and the Gloom cleared.
export type NightRecord = {
	night: number,
	goal: number,
	cleared: number,
}

export type ShiftNightTracker = {
	-- No run yet, or the last one is over: the next preparation starts a new run.
	needsStart: (self: ShiftNightTracker) -> boolean,
	-- A new run in `mode`, from night 1 (forgets everything about the last run).
	start: (self: ShiftNightTracker, mode: RunMode) -> (),
	mode: (self: ShiftNightTracker) -> RunMode,
	-- The night number (nil in a quick run).
	night: (self: ShiftNightTracker) -> number?,
	-- This night's goal (ShiftNightFormulas.nightQuota), kept in the night's record.
	setGoal: (self: ShiftNightTracker, goal: number) -> (),
	-- The night's results for shift `shift`: `cleared` Gloom and whether tonight's goal was `met`; keeps `lives`
	-- (userId -> coats left, 0 for out) for the next night, ends the run when fired or wiped, and holds the week report's
	-- bonus after a survived week. Nil in a quick run, after the run is over, and for a shift already settled.
	settle: (
		self: ShiftNightTracker,
		shift: number,
		cleared: number,
		met: boolean,
		wiped: boolean,
		lives: { [number]: number }
	) -> ShiftNightRules.Settlement?,
	-- Next night: the night number moves on and the week report closes.
	nextNight: (self: ShiftNightTracker) -> (),
	-- Ends the run for `reason` on the current night (kept: the first reason wins).
	finish: (self: ShiftNightTracker, reason: RunOver) -> (),
	isOver: (self: ShiftNightTracker) -> boolean,
	-- The coats each crew member ended the last night with (a copy); nil on a run's first night and in a quick run.
	carried: (self: ShiftNightTracker) -> { [number]: number }?,
	-- Every settled night, oldest first (a copy).
	results: (self: ShiftNightTracker) -> { NightRecord },
	-- The run's fields for the shift's state (ShiftNightRules.stamp).
	view: (self: ShiftNightTracker) -> ShiftNightRules.NightView,
}

local ShiftNightTracker = {}

function ShiftNightTracker.new(): ShiftNightTracker
	local active = false
	local runMode: RunMode = "quick"
	local night = 1
	local goal = 0
	-- The week report's bonus: set when a survived week's last night settles, until the next night.
	local weekBonus: number? = nil
	local lives: { [number]: number }? = nil
	local nights: { NightRecord } = {}
	local runOver: RunOver? = nil
	local nightReached: number? = nil
	local settled: number? = nil

	local tracker: ShiftNightTracker = {
		needsStart = function(_self)
			return not active or runOver ~= nil
		end,

		start = function(_self, mode)
			active = true
			runMode = mode
			night = 1
			goal = 0
			weekBonus = nil
			lives = nil
			table.clear(nights)
			runOver = nil
			nightReached = nil
			settled = nil
		end,

		mode = function(_self)
			return runMode
		end,

		night = function(_self)
			return if active and runMode == "night" then night else nil
		end,

		setGoal = function(_self, next)
			goal = next
		end,

		settle = function(_self, shift, cleared, met, wiped, kept)
			if not active or runMode ~= "night" or runOver ~= nil or settled == shift then
				return nil
			end
			settled = shift
			local settlement = ShiftNightRules.settle({ night = night, met = met, wiped = wiped })
			weekBonus = if settlement.bonus > 0 then settlement.bonus else nil
			lives = table.clone(kept)
			table.insert(nights, { night = night, goal = goal, cleared = math.max(0, cleared) })
			local over: RunOver? = settlement.runOver
			if over then
				runOver = over
				nightReached = night
			end
			return settlement
		end,

		nextNight = function(_self)
			night += 1
			weekBonus = nil
		end,

		finish = function(_self, reason)
			if runOver ~= nil then
				return
			end
			runOver = reason
			nightReached = night
		end,

		isOver = function(_self)
			return runOver ~= nil
		end,

		carried = function(_self)
			local kept = lives
			if runMode ~= "night" or night <= 1 or kept == nil then
				return nil
			end
			return table.clone(kept)
		end,

		results = function(_self)
			return table.clone(nights)
		end,

		view = function(_self)
			if not active or runMode ~= "night" then
				return { runMode = runMode }
			end
			return {
				runMode = runMode,
				night = night,
				week = ShiftNightFormulas.week(night),
				weekBonus = weekBonus,
				runOver = runOver,
				nightReached = nightReached,
			}
		end,
	}
	return tracker
end

return ShiftNightTracker
