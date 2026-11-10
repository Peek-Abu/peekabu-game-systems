--!strict
--[=[
	CoffeeServiceServer: Coffee for the crew (owner 11-08; 30 minutes of shift time, owner 11-10). A Robux developer
	product gives the buyer 30 minutes of coffee time; while it runs the whole crew's Credits pay is doubled, and the
	office PA names the buyer.

	- **Exactly once.** The product's receipt (MarketplaceServiceServer:onProduct) adds CoffeeConstants.SECONDS to the
	  buyer's `coffee` account slice (CoffeeRules.add) in the SAME save that records the receipt, so coffee time is never
	  lost or doubled. Buying again adds 30 minutes. Once that save lands, every player in the server hears the PA.
	- **Countdown.** Once a second, while CoffeeRules.runs (a real shift running, players in the server), the server
	  takes a second off ONE buyer's saved time: the earliest buyer in the server (CoffeeRules.spender), so two coffees
	  never stack past 2x. The hub, the truck ride, the review and training never count. The time left is saved, so it
	  carries across shifts, servers and rejoins.
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
local CoffeeRules = require(ReplicatedStorage.Shared.Features.Coffee.Rules.CoffeeRules)
local MarketplaceRegistry = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceRegistry)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local MarketplaceServiceServer = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
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
local counters = { granted = 0, announced = 0, spent = 0 }
-- Whose coffee the badge shows now (nil = none), so the world entry is cleared once, not every second.
local showing: string? = nil

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
		return
	end
	local candidates: { CoffeeRules.Candidate } = {}
	local byId: { [number]: Player } = {}
	for _, player in players do
		local saved = coffeeSlice.get(player.UserId)
		if saved ~= nil and saved.seconds > 0 then
			table.insert(candidates, { userId = player.UserId, seconds = saved.seconds, since = saved.since })
			byId[player.UserId] = player
		end
	end
	local picked = CoffeeRules.spender(candidates)
	local player = if picked ~= nil then byId[picked.userId] else nil
	if picked == nil or player == nil then
		clearBadge()
		return
	end
	local left = picked.seconds
	local ok = coffeeSlice.mutate(player.UserId, function(value)
		if value.seconds <= 0 then
			return false
		end
		CoffeeRules.spend(value, CoffeeConstants.TICK_SECONDS)
		left = value.seconds
		return true
	end)
	-- A refused write (the profile is busy) spends nothing this second; the badge keeps the last time.
	if not ok then
		return
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
		table.insert(stoppers, function()
			ticking:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stopper in stoppers do
			stopper()
		end
		table.clear(stoppers)
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
			coffee = ShiftServiceServer:coffee(),
		}
	end,
}

return CoffeeServiceServer
