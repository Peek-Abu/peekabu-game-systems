--!strict
--[=[
	AnalyticsEconomySystem: logs an economy event for each Gloom, Credits and Gleam change. Gloom and Credits fire
	on CurrencyServiceServer.changed, Gleam on MarketplaceServiceServer.premiumChanged (the same payload).

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
local AnalyticsEconomyUtils = require(AnalyticsServer.Utils.AnalyticsEconomyUtils)
local CurrencyServiceServer = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local MarketplaceServiceServer = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)

local AnalyticsEconomySystem = {}

--[=[
	Subscribes to the currency and premium change signals. Returns the stopper.
]=]
function AnalyticsEconomySystem.start(sender: AnalyticsTypes.Sender): () -> ()
	local function onChange(change: CurrencyConstants.CurrencyChange)
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
		sender.economy(player, call, { field })
	end
	local currency = CurrencyServiceServer.changed:Connect(onChange)
	local premium = MarketplaceServiceServer.premiumChanged:Connect(onChange)
	return function()
		currency:Disconnect()
		premium:Disconnect()
	end
end

return AnalyticsEconomySystem
