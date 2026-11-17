--!strict
--[=[
	AnalyticsEconomySystem: logs an economy event for each Gloom, Credits and Gleam change. Gloom and Credits fire
	on CurrencyServiceServer.changed, Gleam on MarketplaceServiceServer.premiumChanged (the same payload).

	Most moves never reach those signals: a purchase or reward is a PlayerData transaction (premiumOp, currencyOp),
	which fires nothing. So each feature reports its move once the transaction committed (`record`, through
	AnalyticsServiceServer:recordEconomy): the currency, in or out, the amount, the kind and a bounded sku, with the
	exact item, its rarity and where it happened in the custom fields. The ending balance is read here, after the
	commit. All of it runs only while the economy switch is on (AnalyticsSwitchSystem).

	It is handed a Sender at `start` and never requires AnalyticsServiceServer (that service starts it).

	Spec-exempt shell (signals, Players); the event decision is the specced AnalyticsEconomyUtils.

	@class AnalyticsEconomySystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsServer = ServerScriptService.Features.Analytics

local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local AnalyticsConstants = require(AnalyticsServer.Data.AnalyticsConstants)
local AnalyticsTypes = require(AnalyticsServer.Data.AnalyticsTypes)
local AnalyticsSessionSystem = require(AnalyticsServer.Systems.AnalyticsSessionSystem)
local AnalyticsSwitchSystem = require(AnalyticsServer.Systems.AnalyticsSwitchSystem)
local AnalyticsEconomyUtils = require(AnalyticsServer.Utils.AnalyticsEconomyUtils)
local CurrencyServiceServer = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local MarketplaceServiceServer = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)

local AnalyticsEconomySystem = {}

local sender: AnalyticsTypes.Sender? = nil

-- The player's balance in `currency` now (after the commit); nil while their save is not loaded.
local function balanceOf(userId: number, currency: CurrencyConstants.EconomyCurrency): number?
	local slot: CurrencyConstants.CurrencyType? = CurrencyConstants.toCurrencyType(currency)
	if slot ~= nil then
		if CurrencyServiceServer:getCurrency(userId) == nil then
			return nil
		end
		return CurrencyServiceServer:getCurrencyAmount(userId, slot)
	end
	return MarketplaceServiceServer:getPremium(userId)
end

--[=[
	Logs a move a feature reports after its transaction committed. Nothing while the economy switch is off, before
	`start`, or for a player no longer here.
]=]
function AnalyticsEconomySystem.record(userId: number, record: AnalyticsTypes.EconomyRecord)
	local out = sender
	if out == nil or not AnalyticsSwitchSystem.isOn("economy") then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return
	end
	local call, fields = AnalyticsEconomyUtils.record(
		record,
		balanceOf(userId, record.currency),
		AnalyticsSessionSystem.tracker:cohortOf(userId)
	)
	if call ~= nil then
		out.economy(player, call, fields)
	end
end

--[=[
	Subscribes to the currency and premium change signals. Returns the stopper.
]=]
function AnalyticsEconomySystem.start(out: AnalyticsTypes.Sender): () -> ()
	sender = out
	local function onChange(change: CurrencyConstants.CurrencyChange)
		if not AnalyticsSwitchSystem.isOn("economy") then
			return
		end
		local call = AnalyticsEconomyUtils.call(change)
		if call == nil then
			return
		end
		local player = Players:GetPlayerByUserId(change.userId)
		if player == nil then
			return
		end
		local experiments = AnalyticsConstants.CURRENCY_EXPERIMENTS[change.currency] or {}
		local field = AnalyticsSessionSystem.field(player, experiments, AnalyticsSessionSystem.partyOf(player))
		out.economy(player, call, { field })
	end
	local currency = CurrencyServiceServer.changed:Connect(onChange)
	local premium = MarketplaceServiceServer.premiumChanged:Connect(onChange)
	return function()
		currency:Disconnect()
		premium:Disconnect()
		sender = nil
	end
end

return AnalyticsEconomySystem
