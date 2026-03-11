--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyUtils = require(ReplicatedStorage.Shared.Modules.Utils.CurrencyUtils)
local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local ClientStore = require(ReplicatedStorage.Client.State.ClientStore)

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	A thin read-facade over `ClientStore.currency`, the one client source of truth (populated by
	charm-sync). Reactive UI reads the atom directly via `useAtom`; imperative callers use these
	point-in-time accessors. There is no listener, cache, or signal here — those retired when the
	reactive store became the single client store.
]=]
export type CurrencyServiceClient = {
	dependencies: { string },

	getCurrency: (self: CurrencyServiceClient) -> PlayerDataTypes.Currency?,
	getCurrencyAmount: (self: CurrencyServiceClient, currencyType: CurrencyConstants.CurrencyType) -> number,
	hasCurrency: (self: CurrencyServiceClient, currencyType: CurrencyConstants.CurrencyType, amount: number) -> boolean,
	formatCurrency: (
		self: CurrencyServiceClient,
		amount: number,
		currencyType: CurrencyConstants.CurrencyType?
	) -> string,
	getState: (self: CurrencyServiceClient) -> { [string]: any },
}

local CurrencyServiceClient: CurrencyServiceClient = {
	dependencies = {},

	--[=[
		Gets the local player's currency snapshot from the reactive store.
		@return PlayerDataTypes.Currency? -- The currency data, or nil until the first sync lands
	]=]
	getCurrency = function(_self)
		return ClientStore.currency()
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
		-- `amount` is validated once, by CurrencyUtils.hasEnoughCurrency below — no need to re-assert
		-- it here (the old duplicate check ran the same positive-amount guard twice).
		return CurrencyUtils.hasEnoughCurrency(self:getCurrency(), currencyType, amount)
	end,

	--[=[
		Formats a currency amount for display.
		@param amount number -- The amount to format
		@param currencyType CurrencyConstants.CurrencyType? -- Optional currency type for icon/suffix
		@return string -- The formatted currency string
	]=]
	formatCurrency = function(_self, amount, currencyType)
		-- `amount` is validated by CurrencyUtils.formatCurrency (non-negative number); no duplicate.
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
