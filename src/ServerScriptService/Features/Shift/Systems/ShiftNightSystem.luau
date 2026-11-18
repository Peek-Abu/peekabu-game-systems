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
	- `stamp` / `minTier`: the run's ShiftState fields and the manager's start tier for the night.

	Spec-exempt shell (Round, Currency); the decisions are the specced ShiftNightRules, ShiftNightTracker,
	ShiftNightFormulas and ShiftPaySystem.payAll.

	@class ShiftNightSystem
]=]

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
local ShiftPaySystem = require(ShiftServer.Systems.ShiftPaySystem)
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

local ShiftNightSystem = {}

function ShiftNightSystem.new(deps: Deps): ShiftNightSystem
	local tracker = ShiftNightTracker.new()
	local grant: ShiftPaySystem.Pay = deps.grant or realGrant
	local setDuration: (number) -> () = deps.setDuration or realSetDuration

	local function stillPaying(userId: number): boolean
		return table.find(deps.crewIds(), userId) ~= nil
	end

	local system: ShiftNightSystem = {
		prepare = function(_self, configureRound)
			if tracker:needsStart() then
				-- Training is always a quick shift, however the server got its crew.
				local mode: ShiftTypes.RunMode = if deps.training() then "quick" else deps.mode()
				tracker:start(mode)
				log:info(`a {mode} run starts`)
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
			if settlement.bonus > 0 then
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
			if depot then
				tracker:finish("clockout")
				return "home"
			end
			tracker:nextNight()
			return "next"
		end,

		isOver = function(_self)
			return tracker:isOver()
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
