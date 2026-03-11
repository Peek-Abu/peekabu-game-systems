--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local CurrencySignals = require(ReplicatedStorage.Client.Signals.CurrencySignals)
local CurrencyUtils = require(ReplicatedStorage.Shared.Modules.Utils.CurrencyUtils)
local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local PlayerDataServiceClient = require(ReplicatedStorage.Client.Services.PlayerDataService.PlayerDataServiceClient)

local log = Logger.new("CurrencyServiceClient")

local janitor = Janitor.new()

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	The module below is one annotated table literal (`local CurrencyServiceClient:
	CurrencyServiceClient = { ... }`). Annotating the literal makes Luau push each
	signature from this interface DOWN into the matching method body, so the methods
	need NO inline type annotations — `self` and every parameter are typed from here.
	Types live in exactly one place.
]=]
export type CurrencyServiceClient = {
	dependencies: { string },

	init: (self: CurrencyServiceClient) -> (),
	stop: (self: CurrencyServiceClient) -> (),
	getCurrency: (self: CurrencyServiceClient) -> PlayerDataTypes.Currency?,
	getCurrencyAmount: (self: CurrencyServiceClient, currencyType: CurrencyConstants.CurrencyType) -> number,
	hasCurrency: (
		self: CurrencyServiceClient,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number
	) -> boolean,
	formatCurrency: (
		self: CurrencyServiceClient,
		amount: number,
		currencyType: CurrencyConstants.CurrencyType?
	) -> string,
	getState: (self: CurrencyServiceClient) -> { [string]: any },
}

local CurrencyServiceClient: CurrencyServiceClient = {
	dependencies = { "PlayerDataServiceClient" },

	--[=[
		Initializes the CurrencyServiceClient and sets up event listeners.
		@param self CurrencyServiceClient -- The service instance
	]=]
	init = function(_self)
		-- Require event right before setting up listener
		local CurrencyEvents = require(ReplicatedStorage.Shared.Events.CurrencyEvents)

		-- Listen to network events from server (server is authoritative, no validation needed)
		janitor:Add(CurrencyEvents.packets.CurrencyUpdate.listen(function(data)
			-- Delegate mutation to PlayerDataServiceClient (centralized ownership)
			local mutated = PlayerDataServiceClient:mutate("currency", function(currency: PlayerDataTypes.Currency)
				-- Network trust boundary: the server only ever sends valid currency types, but the wire
				-- value arrives typed as `string`. (A struct-level cast is rejected as "unrelated", so
				-- we assert the value here.)
				currency[data.currencyType :: PlayerDataTypes.CurrencyType] = data.newAmount
				return true
			end)

			-- Fire signal if mutation succeeded (UI subscribes to CurrencySignals.Changed)
			if mutated then
				CurrencySignals.Changed:Fire(data.currencyType, data.newAmount, data.delta)
			end

			-- Log the change for debugging
			if data.delta > 0 then
				log:debug(string.format("Gained %d %s (total: %d)", data.delta, data.currencyType, data.newAmount))
			elseif data.delta < 0 then
				log:debug(
					string.format("Spent %d %s (total: %d)", math.abs(data.delta), data.currencyType, data.newAmount)
				)
			end
		end))
	end,

	--[=[
		Cleans up event listeners when the service is stopped.
		@param self CurrencyServiceClient -- The service instance
	]=]
	stop = function(_self)
		janitor:Cleanup()
		log:debug("Service stopped, connections cleaned up")
	end,

	--[=[
		Gets the local player's currency data.
		@return PlayerDataTypes.Currency? -- The currency data or nil if not loaded
	]=]
	getCurrency = function(_self)
		local profile = PlayerDataServiceClient:getProfile()
		return profile and profile.currency
	end,

	--[=[
		Gets a specific currency amount for the local player.
		@param currencyType CurrencyConstants.CurrencyType -- The currency type
		@return number -- The amount of that currency
	]=]
	getCurrencyAmount = function(self, currencyType)
		assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
		return CurrencyUtils.getCurrencyAmount(self:getCurrency(), currencyType)
	end,

	--[=[
		Checks if the local player has enough of a specific currency.
		@param currencyType CurrencyConstants.CurrencyType -- The currency type
		@param amount number -- The amount to check for
		@return boolean -- True if the player has enough, false otherwise
	]=]
	hasCurrency = function(self, currencyType, amount)
		assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
		assert(
			type(amount) == "number" and amount > 0,
			`amount must be a positive number, got {type(amount)}: {amount}`
		)
		return CurrencyUtils.hasEnoughCurrency(self:getCurrency(), currencyType, amount)
	end,

	--[=[
		Formats a currency amount for display.
		@param amount number -- The amount to format
		@param currencyType CurrencyConstants.CurrencyType? -- Optional currency type for icon/suffix
		@return string -- The formatted currency string
	]=]
	formatCurrency = function(_self, amount, currencyType)
		assert(type(amount) == "number", `amount must be a number, got {type(amount)}`)
		return CurrencyUtils.formatCurrency(amount, currencyType)
	end,

	--[=[
		Returns the current state of the service for debugging.
		@return { [string]: any } -- Service state
	]=]
	getState = function(self)
		local currency = self:getCurrency()
		return {
			hasCurrency = currency ~= nil,
			currency = currency,
		}
	end,
}

return CurrencyServiceClient
