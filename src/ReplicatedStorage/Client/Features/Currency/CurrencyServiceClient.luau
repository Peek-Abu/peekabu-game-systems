--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyUtils = require(ReplicatedStorage.Shared.Features.Currency.Utils.CurrencyUtils)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	A thin read-facade over `StateSyncClientStore.currency`, the one client source of truth (populated by
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
}

local CurrencyServiceClient: CurrencyServiceClient = {
	dependencies = {},

	--[=[
		Gets the local player's currency snapshot from the reactive store.
		@return PlayerDataTypes.Currency? -- The currency data, or nil until the first sync lands
	]=]
	getCurrency = function(_self)
		return StateSyncClientStore.currency()
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
	-- No getState: everything here is a raw mirror of StateSyncClientStore.currency, already shown by the
	-- State tab's synced-slice view — nothing derived or diagnostic to add. See ServiceController's
	-- getState field doc comment for the convention.
}

return CurrencyServiceClient
