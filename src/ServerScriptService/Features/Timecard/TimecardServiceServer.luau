--!strict
--[=[
	TimecardServiceServer: the weekly timecard (design: docs/cleanup-crew-timecard-and-work-order.md).

	Owns the account-wide `timecard` slice. The rules are TimecardCalendarFormulas' (pure, clockless); this service
	only decides WHICH moment a punch answers for (the server clock), commits the punched card, and appends the
	payout ops of the registered `setPayout` handler in the SAME transaction — so a reward is never granted
	without the punch being recorded, or the reverse.

	Punches arrive through TimecardEvents.Punch (rate limited); the replicated slice is what the HUD reads.

	Nothing ticks: a card only changes when its owner punches it. The stored card is rolled forward to the current
	week when the profile loads (so a returning player's slice is current) and again on every punch; a player who
	sits in the hub across the week boundary keeps last week's stored card until they punch, which is harmless
	because the client rolls it for display and the server re-checks the week inside the punch.

	@class TimecardServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local TimecardShared = ReplicatedStorage.Shared.Features.Timecard
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local TimecardCalendarFormulas = require(TimecardShared.Utils.TimecardCalendarFormulas)
local TimecardConstants = require(TimecardShared.Data.TimecardConstants)
local TimecardEvents = require(TimecardShared.Net.TimecardEvents)
local TimecardRules = require(TimecardShared.Rules.TimecardRules)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local Currency = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local Marketplace = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
local Locker = require(ServerScriptService.Features.Locker.LockerServiceServer)
local Depot = require(ServerScriptService.Features.Depot.DepotServiceServer)
local Shift = require(ServerScriptService.Features.Shift.ShiftServiceServer)

type TransactionOperation = PlayerDataService.TransactionOperation

--[=[
	What a landed punch pays, as transaction ops. Called with the punch it is paying for, so one handler covers the
	third punch's key, the fifth's stars and the paycheque. Nil restores the default MVP reward operations.
]=]
export type PayoutFor = (player: Player, result: TimecardCalendarFormulas.PunchResult) -> { TransactionOperation }

local timecardSlice = PlayerDataSliceSystem.registerAccount("timecard", {
	week = 0,
	punched = {},
	weeks = 0,
}, function(account)
	return account.timecard
end, TimecardRules.validate)

local log = Logger.new("TimecardServiceServer")
local punched: SignalTyped.Signal<Player, TimecardCalendarFormulas.PunchResult> = SignalTyped.new()
local function defaultPayout(player: Player, result: TimecardCalendarFormulas.PunchResult): { TransactionOperation }
	local ops: { TransactionOperation } = {}
	if result.milestone == "key" then
		assert(Locker:getLockers(player.UserId) ~= nil, "locker profile not loaded")
		table.insert(ops, {
			userId = player.UserId,
			path = "account.lockers",
			mutator = function(state: PlayerDataTypes.Lockers): boolean
				state.keys.gloom = (state.keys.gloom or 0) + TimecardConstants.KEY_REWARD
				return true
			end,
		})
	end
	if result.milestone == "stars" then
		table.insert(
			ops,
			Marketplace:premiumOp(player.UserId, function(state)
				state.balance += TimecardConstants.STAR_REWARD
				return true
			end)
		)
	end
	if result.paycheck then
		local credits: PlayerDataTypes.CurrencyType = "credits"
		table.insert(
			ops,
			Currency:currencyOp(player.UserId, function(wallet)
				wallet[credits] = (wallet[credits] or 0) + TimecardConstants.PAYCHEQUE_CREDITS
				return true
			end)
		)
	end
	return ops
end
local payoutFor: PayoutFor? = defaultPayout
local canPunchAtHub: ((Player) -> boolean)? = nil
local clock: () -> number = os.time
local stoppers: { () -> () } = {}

--[=[
	Brings a stored card up to `now`'s week, committing the roll (the run can break here). False when the card is
	already on this week, the profile is not loaded, or the write was refused.
]=]
local function roll(userId: number): boolean
	local card = timecardSlice.get(userId)
	if card == nil then
		return false
	end
	local now = clock()
	if card.week == TimecardCalendarFormulas.weekStart(now) then
		return false
	end
	local changed = timecardSlice.mutate(userId, function(stored)
		local rolled = TimecardCalendarFormulas.roll(stored, now)
		if rolled.week == stored.week then
			return false
		end
		stored.week = rolled.week
		stored.punched = rolled.punched
		stored.weeks = rolled.weeks
		return true
	end)
	return changed
end

export type TimecardServiceServer = {
	dependencies: { string },
	punched: SignalTyped.Signal<Player, TimecardCalendarFormulas.PunchResult>,
	init: (self: TimecardServiceServer) -> (),
	stop: (self: TimecardServiceServer) -> (),
	setPayout: (self: TimecardServiceServer, payout: PayoutFor?) -> (),
	setCanPunch: (self: TimecardServiceServer, predicate: ((Player) -> boolean)?) -> (),
	status: (self: TimecardServiceServer, player: Player) -> TimecardRules.Status?,
	punch: (self: TimecardServiceServer, player: Player) -> (boolean, string?),
	roll: (self: TimecardServiceServer, userId: number) -> boolean,
	reset: (self: TimecardServiceServer, userId: number) -> boolean,
	-- Test seam: replace the clock (seconds since the epoch); nil restores os.time.
	_setClock: (self: TimecardServiceServer, nextClock: (() -> number)?) -> (),
	getState: (self: TimecardServiceServer) -> { [string]: string | number | boolean },
}

local TimecardServiceServer: TimecardServiceServer

local onPunch = RequestHandler.wrap({
	name = "TimecardPunch",
	rateLimit = TimecardConstants.PUNCH_RATE,
	handler = function(_data: unknown, player: Player)
		local ok, reason = TimecardServiceServer:punch(player)
		TimecardEvents.packets.Result.sendTo(
			if ok then "Punched! Rewards paid at 3 and 5 days." else reason or "Punch refused. Try again.",
			player
		)
		if not ok then
			log:debug(`timecard punch refused for {player.Name}: {reason or "?"}`)
		end
	end,
})

TimecardServiceServer = {
	dependencies = {
		"PlayerDataServiceServer",
		"CurrencyServiceServer",
		"MarketplaceServiceServer",
		"LockerServiceServer",
	},
	punched = punched,

	init = function(self)
		-- Depot stores callbacks and never requires this service or Shift; this is a forward dependency.
		Depot:setTimecardPhaseReader(function()
			return Shift:getShift().phase
		end)
		self:setCanPunch(function(player)
			return Depot:canPunchTimecard(player)
		end)
		table.insert(
			stoppers,
			TimecardEvents.packets.Punch.listen(function(data: boolean, player: Player?)
				if player then
					onPunch(data, player)
				end
			end)
		)
		-- A returning player's slice must show this week, not the week they last punched in.
		local loaded = PlayerDataService.profileLoaded:Connect(function(userId: number)
			roll(userId)
		end)
		table.insert(stoppers, function()
			loaded:Disconnect()
		end)
		for _, player in Players:GetPlayers() do
			roll(player.UserId)
		end
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		canPunchAtHub = nil
		Depot:setTimecardPhaseReader(nil)
	end,

	--[=[
		The parent game supplies its server-authoritative hub gate. Nil fails closed.
	]=]
	setCanPunch = function(_self, predicate)
		canPunchAtHub = predicate
	end,

	setPayout = function(_self, payout)
		payoutFor = payout or defaultPayout
	end,

	--[=[
		This week's card for the player, or nil when the profile is not loaded.
	]=]
	status = function(_self, player)
		local card = timecardSlice.get(player.UserId)
		if card == nil then
			return nil
		end
		return TimecardRules.status(card, clock())
	end,

	--[=[
		Punches today's clock: the card and its payout commit together. False with a reason when today is already
		punched, the profile is not loaded, or the payout could not be granted.
	]=]
	punch = function(_self, player)
		local card = timecardSlice.get(player.UserId)
		if card == nil then
			return false, "profile not loaded"
		end
		local now = clock()
		local allowed = canPunchAtHub
		if allowed == nil or not allowed(player) then
			return false, "Punch at the hub time clock."
		end
		local preview = TimecardCalendarFormulas.punch(card, now)
		if preview.outcome ~= "punched" then
			return false, "already punched today"
		end
		local ops: { TransactionOperation } = {
			timecardSlice.op(player.UserId, function(stored)
				-- Re-decided against the stored card inside the transaction: two punches racing the same day
				-- settle to one, because the loser rolls this op back.
				local applied = TimecardCalendarFormulas.punch(stored, now)
				if
					applied.outcome ~= "punched"
					or applied.milestone ~= preview.milestone
					or applied.paycheck ~= preview.paycheck
				then
					return false
				end
				stored.week = applied.card.week
				stored.punched = applied.card.punched
				stored.weeks = applied.card.weeks
				return true
			end),
		}
		local payout = payoutFor
		if payout ~= nil then
			local ok, extra = pcall(payout, player, preview)
			if not ok then
				log:error(`timecard payout handler errored: {extra}`)
				return false, "payout handler errored"
			end
			table.move(extra, 1, #extra, #ops + 1, ops)
		end
		local committed, result = PlayerDataService:transaction(ops)
		if not committed then
			return false, result.rejectionReason or "the punch was refused"
		end
		punched:Fire(player, preview)
		return true, nil
	end,

	roll = function(_self, userId)
		return roll(userId)
	end,

	--[=[
		Clears a player's card and paycheque run (admin / testing).
	]=]
	reset = function(_self, userId)
		return timecardSlice.mutate(userId, function(state)
			if state.week == 0 and #state.punched == 0 and state.weeks == 0 then
				return false
			end
			state.week = 0
			state.punched = {}
			state.weeks = 0
			return true
		end)
	end,

	_setClock = function(_self, nextClock)
		clock = nextClock or os.time
	end,

	getState = function(_self)
		local now = clock()
		return {
			week = TimecardCalendarFormulas.weekKey(now),
			today = TimecardCalendarFormulas.dayOfWeek(now),
			punchesToFill = TimecardConstants.PUNCHES_TO_FILL,
			keyPunch = TimecardConstants.KEY_PUNCH,
			paychequeWeeks = TimecardConstants.PAYCHEQUE_WEEKS,
			hasPayout = payoutFor ~= nil,
		}
	end,
}

return TimecardServiceServer
