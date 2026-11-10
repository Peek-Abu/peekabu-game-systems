--!strict
--[=[
	CoffeeServiceServer: Coffee for the crew (owner 11-08; 30 minutes of shift time, owner 11-10). A Robux developer
	product gives the buyer 30 minutes of coffee time; while it runs the whole crew's Credits pay is doubled, and the
	office PA names the buyer.

	- **Gleam.** The same coffee costs CoffeeConstants.GLEAM_PRICE Gleam (owner 11-10): CoffeeEvents.BuyGleam, rate
	  limited, checked on the server (CoffeeRules.affords), then ONE PlayerData transaction takes the Gleam
	  (CoffeeRules.payGleam over the premium slice) and adds the coffee time, so neither lands without the other. A
	  player who is short gets a toast and nothing changes. Coffee is a known item, not a random one, so no
	  PolicyService (paid random items) gate applies.
	- **Exactly once.** The product's receipt (MarketplaceServiceServer:onProduct) adds CoffeeConstants.SECONDS to the
	  buyer's `coffee` account slice (CoffeeRules.add) in the SAME save that records the receipt, so coffee time is never
	  lost or doubled. Buying again adds 30 minutes. Once that save lands, every player in the server hears the PA.
	- **Countdown.** Once a second, while CoffeeRules.runs (a real shift running, players in the server), the server
	  takes a second off ONE buyer's saved time: the earliest buyer in the server (CoffeeRules.spender), so two coffees
	  never stack past 2x. The hub, the truck ride, the review and training never count. The time left is saved, so it
	  carries across shifts, servers and rejoins: spent seconds are written every CoffeeConstants.SAVE_SECONDS (each
	  write is an audited profile mutation), and whenever the countdown stops, the spender changes or the buyer leaves.
	- **The effect.** Each spent second goes to ShiftServiceServer:addCoffee, and the review pays 2x for that part of the
	  shift (CoffeeRules.payScale, ShiftPaySystem). The CoffeeConstants.WORLD_ENTRY world entry ({ buyer, seconds })
	  drives every client's badge countdown; it is cleared whenever no coffee runs.

	Spec-exempt shell (Marketplace, Shift, StateSync and Toast wiring); the decisions are the specced CoffeeRules.

	@class CoffeeServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CoffeeConstants = require(ReplicatedStorage.Shared.Features.Coffee.Data.CoffeeConstants)
local CoffeeEvents = require(ReplicatedStorage.Shared.Features.Coffee.Net.CoffeeEvents)
local CoffeeRules = require(ReplicatedStorage.Shared.Features.Coffee.Rules.CoffeeRules)
local MarketplaceRegistry = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceRegistry)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local MarketplaceServiceServer = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

local coffeeSlice = PlayerDataSliceSystem.registerAccount(CoffeeConstants.SLICE, CoffeeRules.fresh(), function(account)
	return account.coffee
end, CoffeeRules.validate)

local productId = CoffeeConstants.PRODUCT_ID
if productId ~= nil then
	MarketplaceRegistry.registerProduct(CoffeeConstants.PRODUCT_KEY, { productId = productId })
end

local log = Logger.new("CoffeeServiceServer")
local PA_SECONDS = 6

local stoppers: { () -> () } = {}
local counters = { granted = 0, announced = 0, spent = 0, gleamBought = 0, gleamShort = 0 }
-- Whose coffee the badge shows now (nil = none), so the world entry is cleared once, not every second.
local showing: string? = nil
-- Seconds spent but not yet written to each buyer's slice (userId -> seconds).
local pending: { [number]: number } = {}

-- Writes `userId`'s spent seconds to their slice. A refused write (the profile is busy or gone) keeps them pending.
local function save(userId: number)
	local spent = pending[userId]
	if spent == nil or spent <= 0 then
		pending[userId] = nil
		return
	end
	local ok = coffeeSlice.mutate(userId, function(value)
		CoffeeRules.spend(value, spent)
		return true
	end)
	if ok then
		pending[userId] = nil
	end
end

local function saveAll()
	for userId in table.clone(pending) do
		save(userId)
	end
end

-- The PA: every player in this server (the crew) hears who bought the coffee.
local function announce(buyer: string)
	for _, player in Players:GetPlayers() do
		ToastServiceServer:send(player, {
			text = CoffeeRules.paLine(buyer),
			style = ShiftConstants.TOAST_STAMP,
			duration = PA_SECONDS,
		})
	end
end

-- After a purchase: the PA once its save has landed (the buyer's time went up from `before`).
local function announceSoon(player: Player, before: number, tries: number)
	if player.Parent == nil then
		return
	end
	local saved = coffeeSlice.get(player.UserId)
	if saved ~= nil and saved.seconds > before then
		counters.announced += 1
		announce(player.DisplayName)
		return
	end
	if tries > 1 then
		task.delay(CoffeeConstants.PA_RETRY_SECONDS, announceSoon, player, before, tries - 1)
	end
end

-- One coffee bought with Gleam: the Gleam and the coffee time in ONE transaction (both or neither). Coffee is a known
-- item, not a random one, so the PolicyService paid-random-items gate does not apply here.
local function buyWithGleam(player: Player)
	local userId = player.UserId
	if not CoffeeRules.affords(MarketplaceServiceServer:getPremium(userId)) then
		counters.gleamShort += 1
		ToastServiceServer:send(player, { text = CoffeeRules.shortLine() })
		return
	end
	local committed, result = PlayerDataService:transaction({
		MarketplaceServiceServer:premiumOp(userId, CoffeeRules.payGleam),
		coffeeSlice.op(userId, function(value): boolean
			CoffeeRules.add(value, os.time())
			return true
		end),
	})
	if not committed then
		-- The balance changed under us (spent elsewhere) or the profile is busy: nothing was taken.
		counters.gleamShort += 1
		log:warn(`{player.Name}'s Gleam coffee was refused: {result.rejectionReason or "transaction failed"}`)
		ToastServiceServer:send(player, { text = CoffeeRules.shortLine() })
		return
	end
	counters.gleamBought += 1
	log:audit(`userId={userId}`, "COFFEE_GLEAM_BOUGHT", CoffeeConstants.GLEAM_PRICE)
	announce(player.DisplayName)
end

local onBuyGleam = RequestHandler.wrap({
	name = "CoffeeBuyGleam",
	rateLimit = { maxRequests = 3, windowSeconds = 5 },
	handler = function(_payload: unknown, player: Player)
		buyWithGleam(player)
	end,
})

local function clearBadge()
	if showing ~= nil then
		showing = nil
		StateSyncWorldStore.clear(CoffeeConstants.WORLD_ENTRY)
	end
end

-- One countdown second: spends a second of the earliest buyer's coffee time while a real shift runs.
local function tick()
	local players = Players:GetPlayers()
	local shift = ShiftServiceServer:getShift()
	if not CoffeeRules.runs(shift.phase, ShiftServiceServer:isTraining(), #players) then
		clearBadge()
		saveAll()
		return
	end
	local candidates: { CoffeeRules.Candidate } = {}
	local byId: { [number]: Player } = {}
	for _, player in players do
		local saved = coffeeSlice.get(player.UserId)
		-- What is left: the saved time minus the seconds spent since the last write.
		local seconds = if saved ~= nil then saved.seconds - (pending[player.UserId] or 0) else 0
		if saved ~= nil and seconds > 0 then
			table.insert(candidates, { userId = player.UserId, seconds = seconds, since = saved.since })
			byId[player.UserId] = player
		end
	end
	local picked = CoffeeRules.spender(candidates)
	local player = if picked ~= nil then byId[picked.userId] else nil
	-- Anyone else's spent seconds (the spender changed, or theirs ran out) are written now.
	for userId in table.clone(pending) do
		if picked == nil or userId ~= picked.userId then
			save(userId)
		end
	end
	if picked == nil or player == nil then
		clearBadge()
		return
	end
	local userId = player.UserId
	local spent = (pending[userId] or 0) + CoffeeConstants.TICK_SECONDS
	pending[userId] = spent
	local left = math.max(0, picked.seconds - CoffeeConstants.TICK_SECONDS)
	if spent >= CoffeeConstants.SAVE_SECONDS or left <= 0 then
		save(userId)
	end
	counters.spent += 1
	local buyer = player.DisplayName
	ShiftServiceServer:addCoffee(buyer, CoffeeConstants.TICK_SECONDS)
	if left > 0 then
		showing = buyer
		StateSyncWorldStore.set(CoffeeConstants.WORLD_ENTRY, { buyer = buyer, seconds = left })
	else
		-- Used up: the next buyer in line (if any) shows from the next second.
		clearBadge()
	end
end

export type CoffeeServiceServer = {
	dependencies: { string },
	start: (self: CoffeeServiceServer) -> (),
	stop: (self: CoffeeServiceServer) -> (),
	getState: (self: CoffeeServiceServer) -> { [string]: any },
}

local CoffeeServiceServer: CoffeeServiceServer = {
	dependencies = {
		"PlayerDataServiceServer",
		"MarketplaceServiceServer",
		"ShiftServiceServer",
		"StateSyncServiceServer",
		"ToastServiceServer",
	},

	start = function(_self)
		if productId ~= nil then
			MarketplaceServiceServer:onProduct(CoffeeConstants.PRODUCT_KEY, function(player: Player)
				counters.granted += 1
				local saved = coffeeSlice.get(player.UserId)
				local before = if saved ~= nil then saved.seconds else 0
				task.defer(announceSoon, player, before, CoffeeConstants.PA_TRIES)
				log:info(`{player.Name} bought coffee for the crew`)
				return {
					coffeeSlice.op(player.UserId, function(value): boolean
						CoffeeRules.add(value, os.time())
						return true
					end),
				}
			end)
		end
		local elapsed = 0
		local ticking = RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			if elapsed < CoffeeConstants.TICK_SECONDS then
				return
			end
			elapsed -= CoffeeConstants.TICK_SECONDS
			-- A long hitch spends one second, never a burst.
			elapsed = math.min(elapsed, CoffeeConstants.TICK_SECONDS)
			local ok, err = pcall(tick)
			if not ok then
				log:error(`coffee tick failed: {err}`)
			end
		end)
		local buying = CoffeeEvents.packets.BuyGleam.listen(function(payload: unknown, player: Player?)
			if player ~= nil then
				onBuyGleam(payload, player)
			end
		end)
		-- A leaving buyer's spent seconds are written before their profile is released.
		local leaving = Players.PlayerRemoving:Connect(function(player: Player)
			save(player.UserId)
			pending[player.UserId] = nil
		end)
		table.insert(stoppers, function()
			ticking:Disconnect()
			leaving:Disconnect()
			buying()
		end)
	end,

	stop = function(_self)
		for _, stopper in stoppers do
			stopper()
		end
		table.clear(stoppers)
		saveAll()
		table.clear(pending)
		showing = nil
		StateSyncWorldStore.clear(CoffeeConstants.WORLD_ENTRY)
	end,

	getState = function(_self)
		local saved: { [string]: number } = {}
		for _, player in Players:GetPlayers() do
			local value = coffeeSlice.get(player.UserId)
			if value ~= nil then
				saved[player.Name] = value.seconds
			end
		end
		return {
			counters = table.clone(counters),
			product = productId,
			showing = showing,
			saved = saved,
			pending = table.clone(pending),
			coffee = ShiftServiceServer:coffee(),
		}
	end,
}

return CoffeeServiceServer
