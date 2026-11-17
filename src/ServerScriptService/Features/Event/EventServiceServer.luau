--!strict
--[=[
	EventServiceServer: limited-time events (EventRegistry) on the server.

	- `live()`: the event live now (its dates, or the admin preview set by the EventPreview command, a Workspace
	  attribute every client sees too).
	- Pay: when a shift's review opens (EventPaySystem), each crew member gets the live event's money for the shift
	  (EventPayFormulas: base, contract, first finished shift of the day, a Roblox friend in the crew), written in ONE
	  transaction with the account `events` slice that remembers the day the first-shift bonus was paid. The player is
	  sent EventEvents.Paid for the results screen. Training pays nothing; coffee and passes never multiply it.
	- After an event: on each profile load, while no event is live, leftover money of an event that has ended turns
	  into its `convertTo` currency at `convertRate` (one currency write).
	- In a shift, about one acorn hides under a cleared pile (EventPickupSystem); the first to touch it gets the event's
	  pickup amount.
	- Hub props tagged `EventProp` (attribute `Event` = event id) are shown only while that event is live
	  (EventPropSystem).

	@class EventServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local DailyRewardConstants = require(ReplicatedStorage.Shared.Features.DailyReward.Data.DailyRewardConstants)
local EventShared = ReplicatedStorage.Shared.Features.Event
local EventConstants = require(EventShared.Data.EventConstants)
local EventEvents = require(EventShared.Net.EventEvents)
local EventPayFormulas = require(EventShared.Utils.EventPayFormulas)
local EventRegistry = require(EventShared.Data.EventRegistry)
local EventRules = require(EventShared.Rules.EventRules)
local EventTypes = require(EventShared.Data.EventTypes)
local EventUtils = require(EventShared.Utils.EventUtils)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local EventPaySystem = require(ServerScriptService.Features.Event.Systems.EventPaySystem)
local EventPropSystem = require(ServerScriptService.Features.Event.Systems.EventPropSystem)
local EventPickupSystem = require(ServerScriptService.Features.Event.Systems.EventPickupSystem)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local AnalyticsServiceServer = require(ServerScriptService.Features.Analytics.AnalyticsServiceServer)
local CurrencyServiceServer = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)

type Event = EventTypes.Event

local eventsSlice = PlayerDataSliceSystem.registerAccount("events", { day = 0, shown = {} }, function(account)
	return account.events
end, EventRules.validate)

export type Paid = { event: string, total: number, parts: { string } }

export type Deps = {
	now: () -> number,
	preview: () -> string?,
	isFriend: (userId: number, other: number) -> boolean,
	sendPaid: (userId: number, payload: Paid) -> (),
}

local log = Logger.new("EventServiceServer")
local janitor = Janitor.new()
local stoppers: { () -> () } = {}
-- Friend checks yield (a web call): remembered per pair for the server's life.
local friendCache: { [string]: boolean } = {}

local defaults: Deps = {
	now = os.time,
	preview = function(): string?
		local value = workspace:GetAttribute(EventConstants.PREVIEW_ATTRIBUTE)
		return if type(value) == "string" then value else nil
	end,
	isFriend = function(userId, other)
		local key = if userId < other then `{userId}:{other}` else `{other}:{userId}`
		local cached = friendCache[key]
		if cached ~= nil then
			return cached
		end
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			return false
		end
		local ok, result = pcall(function(): boolean
			return player:IsFriendsWith(other)
		end)
		local friends = ok and result == true
		if ok then
			friendCache[key] = friends
		end
		return friends
	end,
	sendPaid = function(userId, payload)
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			EventEvents.packets.Paid.sendTo(payload, player)
		end
	end,
}
local deps: Deps = defaults

local function liveImpl(): Event?
	return EventUtils.live(EventRegistry.all(), deps.now(), deps.preview())
end

local function payShiftImpl(userId: number, event: Event, results: ShiftTypes.ShiftResults, crew: { number }): boolean
	Guard.userId(userId)
	local state = eventsSlice.get(userId)
	if state == nil or CurrencyServiceServer:getCurrency(userId) == nil then
		return false
	end
	local today = EventUtils.day(deps.now(), DailyRewardConstants.DAY_OFFSET_HOURS)
	local firstToday = state.day ~= today
	local withFriend = false
	for _, other in crew do
		if other ~= userId and deps.isFriend(userId, other) then
			withFriend = true
			break
		end
	end
	local payout = EventPayFormulas.payout(event.pay, {
		quotaMet = results.quotaMet,
		firstToday = firstToday,
		withFriend = withFriend,
	})
	if payout.total <= 0 then
		return true
	end
	local currency: CurrencyConstants.CurrencyType = event.currency
	local total = payout.total
	local committed, result = PlayerDataService:transaction({
		eventsSlice.op(userId, function(saved): boolean
			if firstToday then
				-- Another server paid today's bonus in between: refuse, so the retry works it out again.
				if saved.day == today then
					return false
				end
				saved.day = today
			end
			return true
		end),
		CurrencyServiceServer:currencyOp(userId, function(wallet): boolean
			wallet[currency] = math.min((wallet[currency] or 0) + total, CurrencyConstants.MAX_CURRENCY)
			return true
		end),
	})
	if not committed then
		log:debug(`event pay for {userId} not written: {result.rejectionReason or "?"}`)
		return false
	end
	local parts: { string } = {}
	for _, part in payout.parts do
		table.insert(parts, part)
	end
	log:audit(`userId={userId}`, "EVENT_PAID", event.id, total, table.concat(parts, "+"))
	AnalyticsServiceServer:recordEconomy(userId, {
		currency = currency,
		flow = "source",
		amount = total,
		kind = "Gameplay",
		sku = "reward:event_shift",
		item = event.id,
		where = if firstToday then "first_today" else "shift",
	})
	deps.sendPaid(userId, { event = event.id, total = total, parts = parts })
	return true
end

-- The event that most recently ended with this money (its conversion applies), or nil.
local function lastEnded(currency: CurrencyConstants.CurrencyType, now: number): Event?
	local found: Event? = nil
	for _, event in EventRegistry.all() do
		if event.currency == currency and event.ends <= now and (found == nil or event.ends > found.ends) then
			found = event
		end
	end
	return found
end

local function convertImpl(userId: number): boolean
	Guard.userId(userId)
	if liveImpl() ~= nil then
		return false
	end
	local wallet = CurrencyServiceServer:getCurrency(userId)
	if wallet == nil then
		return false
	end
	local now = deps.now()
	local changed = false
	for _, currency: CurrencyConstants.CurrencyType in CurrencyConstants.getValidCurrencies() do
		local leftover = wallet[currency] or 0
		local event = lastEnded(currency, now)
		if leftover > 0 and event ~= nil then
			local into: CurrencyConstants.CurrencyType = event.convertTo
			local rate = event.convertRate
			local committed = PlayerDataService:transaction({
				CurrencyServiceServer:currencyOp(userId, function(saved): boolean
					local have = saved[currency] or 0
					if have <= 0 then
						return false
					end
					saved[currency] = 0
					saved[into] = math.min(
						(saved[into] or 0) + EventPayFormulas.converted(have, rate),
						CurrencyConstants.MAX_CURRENCY
					)
					return true
				end),
			})
			if committed then
				changed = true
				log:audit(`userId={userId}`, "EVENT_CONVERTED", event.id, leftover, into)
				AnalyticsServiceServer:recordEconomy(userId, {
					currency = currency,
					flow = "sink",
					amount = leftover,
					kind = "Gameplay",
					sku = "event_convert",
					item = event.id,
					where = "event_end",
				})
				AnalyticsServiceServer:recordEconomy(userId, {
					currency = into,
					flow = "source",
					amount = EventPayFormulas.converted(leftover, rate),
					kind = "Gameplay",
					sku = "event_convert",
					item = event.id,
					where = "event_end",
				})
			end
		end
	end
	return changed
end

-- Remembers that the player was shown a live event's Shop tab (the Shop opens on it only the first time).
local function markShownImpl(userId: number, eventId: string): boolean
	Guard.userId(userId)
	local event = liveImpl()
	if event == nil or event.id ~= eventId then
		return false
	end
	local changed = eventsSlice.mutate(userId, function(saved): boolean
		if saved.shown[eventId] == true then
			return false
		end
		saved.shown[eventId] = true
		return true
	end)
	return changed
end

local onShownRequest = RequestHandler.wrap({
	name = "EventShownRequest",
	rateLimit = { maxRequests = 3, windowSeconds = 10 },
	handler = function(payload: unknown, player: Player)
		local eventId = EventRules.parseShown(payload)
		if eventId == nil then
			log:warn(`bad Shown request from {player.Name}`)
			return
		end
		markShownImpl(player.UserId, eventId)
	end,
})

export type EventServiceServer = {
	dependencies: { string },
	start: (self: EventServiceServer) -> (),
	stop: (self: EventServiceServer) -> (),
	-- The event live now (dates or admin preview), or nil.
	live: (self: EventServiceServer) -> Event?,
	-- Pays one crew member their share of a finished shift; false when it could not be written (retry).
	payShift: (
		self: EventServiceServer,
		userId: number,
		event: Event,
		results: ShiftTypes.ShiftResults,
		crew: { number }
	) -> boolean,
	-- Remembers the player was shown a live event's Shop tab; true when it was new.
	markShown: (self: EventServiceServer, userId: number, eventId: string) -> boolean,
	-- Turns leftover money of an ended event into its other currency; true when anything changed.
	convertLeftover: (self: EventServiceServer, userId: number) -> boolean,
	getState: (self: EventServiceServer) -> { [string]: any },
	-- TEST SEAM: the clock, preview, friend check and Paid sender (nil restores the real ones).
	_setDeps: (replacement: Deps?) -> (),
}

local EventServiceServer: EventServiceServer = {
	dependencies = {
		"PlayerDataServiceServer",
		"CurrencyServiceServer",
		"ShiftServiceServer",
		"VacuumServiceServer",
		"ToastServiceServer",
		"AnalyticsServiceServer",
	},

	start = function(self)
		janitor:Add(
			EventEvents.packets.Shown.listen(function(payload: unknown, player: Player?)
				if player then
					onShownRequest(payload, player)
				end
			end),
			true
		)
		janitor:Add(
			PlayerDataService.profileLoaded:Connect(function(userId: number)
				self:convertLeftover(userId)
			end),
			"Disconnect"
		)
		janitor:Add(
			Players.PlayerRemoving:Connect(function(player: Player)
				local id = tostring(player.UserId)
				for key in friendCache do
					if string.find(key, id, 1, true) ~= nil then
						friendCache[key] = nil
					end
				end
			end),
			"Disconnect"
		)
		table.insert(
			stoppers,
			EventPaySystem.start({
				changed = ShiftServiceServer.changed,
				results = function()
					return ShiftServiceServer:getResults()
				end,
				present = function()
					local ids: { number } = {}
					for _, player in Players:GetPlayers() do
						table.insert(ids, player.UserId)
					end
					return ids
				end,
				training = function()
					return ShiftServiceServer:isTraining()
				end,
				live = liveImpl,
			}, payShiftImpl)
		)
		table.insert(
			stoppers,
			EventPickupSystem.start({
				changed = ShiftServiceServer.changed,
				cleared = VacuumServiceServer.pileCleared,
				live = liveImpl,
				training = function()
					return ShiftServiceServer:isTraining()
				end,
				grant = function(userId, event, amount)
					if not CurrencyServiceServer:addCurrency(userId, event.currency, amount) then
						return false
					end
					log:audit(`userId={userId}`, "EVENT_PICKUP", event.id, amount)
					AnalyticsServiceServer:recordEconomy(userId, {
						currency = event.currency,
						flow = "source",
						amount = amount,
						kind = "Gameplay",
						sku = "reward:event_pickup",
						item = event.id,
						where = "shift",
					})
					local player = Players:GetPlayerByUserId(userId)
					if player ~= nil then
						ToastServiceServer:send(player, { text = `You found an acorn! +{amount}` })
					end
					return true
				end,
			})
		)
		table.insert(
			stoppers,
			EventPropSystem.start({
				live = function(): string?
					local event = liveImpl()
					return if event ~= nil then event.id else nil
				end,
				tagged = function()
					return CollectionService:GetTagged(EventConstants.PROP_TAG)
				end,
				added = CollectionService:GetInstanceAddedSignal(EventConstants.PROP_TAG),
				store = ServerStorage,
			})
		)
	end,

	stop = function(_self)
		janitor:Cleanup()
		for _, stopper in stoppers do
			stopper()
		end
		table.clear(stoppers)
		table.clear(friendCache)
	end,

	live = function(_self)
		return liveImpl()
	end,

	payShift = function(_self, userId, event, results, crew)
		return payShiftImpl(userId, event, results, crew)
	end,

	markShown = function(_self, userId, eventId)
		return markShownImpl(userId, eventId)
	end,

	convertLeftover = function(_self, userId)
		return convertImpl(userId)
	end,

	getState = function(_self)
		local event = liveImpl()
		return { live = if event ~= nil then event.id else "none", events = #EventRegistry.all() }
	end,

	_setDeps = function(replacement)
		deps = replacement or defaults
	end,
}

return EventServiceServer
