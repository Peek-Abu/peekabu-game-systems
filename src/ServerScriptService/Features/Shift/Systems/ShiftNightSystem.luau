--!strict
--[=[
	ShiftNightSystem: the Night Shift run on top of the shift loop (ShiftNightConstants). The run's record is
	ShiftNightTracker's (outside the per-run clearing); this system applies it to each night and settles each night:

	- `prepare` (the transit's step, before the site is built): starts a run when none is going (the mode from the
	  crew's depart payload, ShiftTripSystem.mode) and sets Round's duration for the night (ShiftNightFormulas.seconds;
	  a quick shift gets the normal SHIFT_SECONDS back) before `startNow`;
	- `goal`: the night's goal from the shift contract (ShiftNightFormulas.nightQuota; a quick shift keeps the contract),
	  the night's only fail line;
	- `carried`: the coats each crew member ended the last night with (ShiftLivesSystem.begin carries them);
	- `payScale`: the night's pay multiplier (ShiftNightFormulas.payScale, folded into the review's payScale, so
	  ShiftPaySystem pays it once per shift as before);
	- `settle` (each night's results, once per shift): a missed goal fires the crew and a wipe ends the run; surviving a
	  week's last night pays every present crew member the week bonus in Credits (ShiftPaySystem.payAll through the
	  same Currency grant as a shift's pay) and shows the week report (the state's `weekBonus`);
	- `decide` (the vote): Next night moves the run on, Clock out ends it and sends the crew home with their pay; a run
	  already over (fired or wiped) always goes home;
	- `extraTime` (Round's extraTime hook, when a night's clock runs out): ShiftNightRules.extraTime's seconds, once a
	  night (reset as each night is prepared);
	- `stamp` / `minTier`: the run's ShiftState fields and the manager's start tier for the night;
	- analytics (ShiftNightAnalyticsUtils, to every crew member in the server, behind Analytics' `nightShift` switch):
	  the mode when a run starts, each night as it is prepared (once a night), the vote's result, how the run ended
	  and each week completed. One event per happening, never per tick; training sends none.

	Spec-exempt shell (Round, Currency); the decisions are the specced ShiftNightRules, ShiftNightTracker,
	ShiftNightFormulas and ShiftPaySystem.payAll.

	@class ShiftNightSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local RoundConstants = require(ReplicatedStorage.Shared.Features.Round.Data.RoundConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftNightFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftNightFormulas)
local ShiftServer = ServerScriptService.Features.Shift
local ShiftNightRules = require(ShiftServer.Rules.ShiftNightRules)
local ShiftNightTracker = require(ShiftServer.State.ShiftNightTracker)
local ShiftNightAnalyticsUtils = require(ShiftServer.Utils.ShiftNightAnalyticsUtils)
local ShiftPaySystem = require(ShiftServer.Systems.ShiftPaySystem)
local AnalyticsServiceServer = require(ServerScriptService.Features.Analytics.AnalyticsServiceServer)
local CurrencyServiceServer = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)

export type Deps = {
	-- The run mode the crew's depart payload carried (ShiftTripSystem.mode).
	mode: () -> ShiftTypes.RunMode,
	-- The crew members in the server (the week bonus goes to them).
	crewIds: () -> { number },
	-- A training run (no start tier).
	training: () -> boolean,
	-- Effects; absent = the real ones.
	grant: ShiftPaySystem.Pay?,
	setDuration: ((seconds: number) -> ())?,
	-- Sends one analytics record to a crew member (absent = AnalyticsServiceServer:nightShift).
	report: ((userId: number, record: ShiftNightAnalyticsUtils.Record) -> ())?,
}

-- What the vote's result does: send the crew home, or play the next night (a quick shift's Another shift).
export type Decision = "home" | "next"

export type ShiftNightSystem = {
	prepare: (self: ShiftNightSystem, configureRound: boolean) -> (),
	goal: (self: ShiftNightSystem, contract: number) -> number,
	carried: (self: ShiftNightSystem) -> { [number]: number }?,
	payScale: (self: ShiftNightSystem) -> number,
	settle: (
		self: ShiftNightSystem,
		state: ShiftTypes.ShiftState,
		results: ShiftTypes.ShiftResults?,
		lives: { [number]: number }
	) -> (),
	decide: (self: ShiftNightSystem, depot: boolean) -> Decision,
	extraTime: (self: ShiftNightSystem, quota: number, cleared: number, quotaMet: boolean) -> number,
	isOver: (self: ShiftNightSystem) -> boolean,
	stamp: (self: ShiftNightSystem, state: ShiftTypes.ShiftState) -> ShiftTypes.ShiftState,
	minTier: (self: ShiftNightSystem) -> number,
}

local log = Logger.new("ShiftNightSystem")

local function realGrant(userId: number, amounts: CurrencyConstants.Amounts): boolean
	return CurrencyServiceServer:grant(userId, amounts, "shiftPay")
end

local function realSetDuration(seconds: number)
	RoundServiceServer:configure({ duration = seconds })
end

local function realReport(userId: number, record: ShiftNightAnalyticsUtils.Record)
	local player = Players:GetPlayerByUserId(userId)
	if player ~= nil then
		AnalyticsServiceServer:nightShift(player, record.event, record.value, record.fields)
	end
end

local ShiftNightSystem = {}

function ShiftNightSystem.new(deps: Deps): ShiftNightSystem
	local tracker = ShiftNightTracker.new()
	local grant: ShiftPaySystem.Pay = deps.grant or realGrant
	local setDuration: (number) -> () = deps.setDuration or realSetDuration
	local reportTo: (number, ShiftNightAnalyticsUtils.Record) -> () = deps.report or realReport
	-- The last night reported as reached (prepare may run twice for one night), reset with each run.
	local reportedNight = 0
	-- Whether this night already had its extra time (reset as each night is prepared).
	local extraUsed = false

	local function report(record: ShiftNightAnalyticsUtils.Record)
		if deps.training() then
			return
		end
		for _, userId in deps.crewIds() do
			reportTo(userId, record)
		end
	end

	local function stillPaying(userId: number): boolean
		return table.find(deps.crewIds(), userId) ~= nil
	end

	local system: ShiftNightSystem = {
		prepare = function(_self, configureRound)
			extraUsed = false
			if tracker:needsStart() then
				-- Training is always a quick shift, however the server got its crew.
				local mode: ShiftTypes.RunMode = if deps.training() then "quick" else deps.mode()
				tracker:start(mode)
				reportedNight = 0
				log:info(`a {mode} run starts`)
				report(ShiftNightAnalyticsUtils.mode(mode))
			end
			local reached = tracker:night()
			if reached ~= nil and reached > reportedNight then
				reportedNight = reached
				report(ShiftNightAnalyticsUtils.night(reached))
			end
			if not configureRound then
				return
			end
			local night = tracker:night()
			setDuration(if night ~= nil then ShiftNightFormulas.seconds(night) else ShiftConstants.SHIFT_SECONDS)
		end,

		goal = function(_self, contract)
			local night = tracker:night()
			if night == nil then
				return contract
			end
			local goal = ShiftNightFormulas.nightQuota(contract, night)
			tracker:setGoal(goal)
			return goal
		end,

		carried = function(_self)
			return tracker:carried()
		end,

		payScale = function(_self)
			local night = tracker:night()
			return if night ~= nil then ShiftNightFormulas.payScale(night) else 1
		end,

		settle = function(_self, state, results, lives)
			local night = tracker:night()
			if night == nil or results == nil then
				return
			end
			local settlement = tracker:settle(
				state.shift,
				results.cleared,
				results.quotaMet,
				state.outcome == RoundConstants.OUTCOME_WIPED,
				lives
			)
			if settlement == nil then
				return
			end
			log:info(
				`night {night} settled: {results.cleared}/{results.quota}, bonus {settlement.bonus}, {settlement.runOver or "on"}`
			)
			if settlement.runOver ~= nil then
				report(ShiftNightAnalyticsUtils.runEnd(settlement.runOver, night))
			end
			if settlement.bonus > 0 then
				report(ShiftNightAnalyticsUtils.weekDone(ShiftNightFormulas.week(night), settlement.bonus))
				ShiftPaySystem.payAll(
					`week {ShiftNightFormulas.week(night)} bonus`,
					deps.crewIds(),
					{ credits = settlement.bonus },
					grant,
					stillPaying
				)
			end
		end,

		decide = function(_self, depot)
			if tracker:night() == nil then
				return if depot then "home" else "next"
			end
			if tracker:isOver() then
				return "home"
			end
			local night = tracker:night() or 1
			report(ShiftNightAnalyticsUtils.vote(depot, night))
			if depot then
				tracker:finish("clockout")
				report(ShiftNightAnalyticsUtils.runEnd("clockout", night))
				return "home"
			end
			tracker:nextNight()
			return "next"
		end,

		isOver = function(_self)
			return tracker:isOver()
		end,

		extraTime = function(_self, quota, cleared, quotaMet)
			local seconds = ShiftNightRules.extraTime({
				night = tracker:night(),
				training = deps.training(),
				used = extraUsed,
				quota = quota,
				cleared = cleared,
				quotaMet = quotaMet,
			})
			if seconds > 0 then
				extraUsed = true
				log:info(`night {tracker:night() or 0} gets {seconds} s of extra time at {cleared}/{quota}`)
			end
			return seconds
		end,

		stamp = function(_self, state)
			return ShiftNightRules.stamp(state, tracker:view(), deps.training())
		end,

		minTier = function(_self)
			return ShiftNightRules.minTier(tracker:mode(), tracker:night(), deps.training())
		end,
	}
	return system
end

return ShiftNightSystem
