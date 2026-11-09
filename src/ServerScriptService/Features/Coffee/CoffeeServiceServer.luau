--!strict
--[=[
	CoffeeServiceServer: Coffee for the crew (owner 11-08). A Robux developer product bought during a shift doubles the
	whole crew's Credits pay for that shift, and the office PA names the buyer.

	- **Exactly once.** The product's receipt (MarketplaceServiceServer:onProduct) adds one unspent coffee to the
	  buyer's `coffee` account slice in the SAME save that records the receipt, so a coffee is never lost or doubled.
	- **Spending.** Then this service spends it on the running shift (CoffeeRules.spends: a real shift running, no
	  coffee yet), retrying while that save lands. One that cannot be spent (no shift running, a training run, or
	  coffee already on) stays saved: the shift HUD then shows FREE, and the player's tap (CoffeeEvents.Use) spends it.
	- **The effect.** ShiftServiceServer:setCoffee(buyer) doubles the review's pay (ShiftPaySystem), the
	  CoffeeConstants.WORLD_ENTRY world entry names the buyer for every client's badge, and every player in the
	  server gets the PA line as a stamp toast. The entry goes when the shift's coffee is cleared.

	Until the owner creates the developer product (CoffeeConstants.PRODUCT_ID), no receipt can arrive; saved coffees
	still work.

	Spec-exempt shell (Marketplace, Shift, StateSync and Toast wiring); the decisions are the specced CoffeeRules.

	@class CoffeeServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CoffeeConstants = require(ReplicatedStorage.Shared.Features.Coffee.Data.CoffeeConstants)
local CoffeeEvents = require(ReplicatedStorage.Shared.Features.Coffee.Net.CoffeeEvents)
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
local counters = { granted = 0, brewed = 0, kept = 0 }

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

-- Spends one of `player`'s saved coffees on the running shift when CoffeeRules.spends says so. True when it did.
local function trySpend(player: Player): boolean
	local shift = ShiftServiceServer:getShift()
	local training = ShiftServiceServer:isTraining()
	local active = ShiftServiceServer:coffee() ~= nil
	local saved = coffeeSlice.get(player.UserId)
	if saved == nil or not CoffeeRules.spends(shift.phase, training, active, saved.vouchers) then
		return false
	end
	local ok = coffeeSlice.mutate(player.UserId, function(value)
		if value.vouchers <= 0 then
			return false
		end
		value.vouchers -= 1
		return true
	end)
	if not ok then
		return false
	end
	local buyer = player.DisplayName
	ShiftServiceServer:setCoffee(buyer)
	StateSyncWorldStore.set(CoffeeConstants.WORLD_ENTRY, buyer)
	announce(buyer)
	counters.brewed += 1
	log:info(`{player.Name} bought coffee for the crew (shift {shift.shift})`)
	return true
end

-- After a purchase: spend the new coffee once its save has landed, else it stays saved for the FREE button.
local function spendSoon(player: Player, tries: number)
	if player.Parent == nil or trySpend(player) then
		return
	end
	if tries <= 1 then
		counters.kept += 1
		return
	end
	task.delay(CoffeeConstants.SPEND_RETRY_SECONDS, spendSoon, player, tries - 1)
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
				task.defer(spendSoon, player, CoffeeConstants.SPEND_TRIES)
				return {
					coffeeSlice.op(player.UserId, function(value): boolean
						value.vouchers += 1
						return true
					end),
				}
			end)
		end
		local using = CoffeeEvents.packets.Use.listen(function(_value: boolean, player: Player?)
			if player ~= nil then
				trySpend(player)
			end
		end)
		-- The badge goes with the shift's coffee (ShiftServiceServer clears it with the run).
		local following = ShiftServiceServer.changed:Connect(function()
			if ShiftServiceServer:coffee() == nil then
				StateSyncWorldStore.clear(CoffeeConstants.WORLD_ENTRY)
			end
		end)
		table.insert(stoppers, function()
			using()
			following:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stopper in stoppers do
			stopper()
		end
		table.clear(stoppers)
		StateSyncWorldStore.clear(CoffeeConstants.WORLD_ENTRY)
	end,

	getState = function(_self)
		return {
			counters = table.clone(counters),
			product = productId,
			coffee = ShiftServiceServer:coffee(),
		}
	end,
}

return CoffeeServiceServer
