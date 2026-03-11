--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local Guard = require(ReplicatedStorage.Shared.Modules.Guard)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local CurrencyUtils = require(ReplicatedStorage.Shared.Modules.Utils.CurrencyUtils)
local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)
local SliceOwner = require(ServerScriptService.Modules.SliceOwner)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService.PlayerDataServiceServer)

-- The currency invariant, enforced by the DATA LAYER on every write (see SliceOwner's `validate`).
-- The service methods below already respect it, but registering it here makes it hold for ANY path
-- into the slice — including a raw `PlayerDataService:transaction()` op (e.g. a trade) that never
-- goes through addCurrency/setCurrency. Without this the cap was a service-method convention, not a
-- guarantee. Runs after a mutator, inside the no-yield region, so it must stay pure/synchronous.
local function validateCurrency(currency: PlayerDataTypes.Currency): (boolean, string?)
	for key, value in currency do
		-- The key set is part of the invariant, not just the values: a raw op writing an unknown
		-- key (`currency.dogecoin = 5`) would otherwise be persisted AND replicated to the client
		-- atom, bypassing CurrencyConstants as the single source of truth for what currencies exist.
		if not CurrencyConstants.isValidCurrencyType(key) then
			return false, `currency key "{key}" is not a registered currency`
		end
		if type(value) ~= "number" then
			return false, `currency "{key}" must be a number, got {type(value)}`
		end
		if value < 0 then
			return false, `currency "{key}" is negative ({value})`
		end
		if value > CurrencyConstants.MAX_CURRENCY then
			return false, `currency "{key}" exceeds MAX_CURRENCY ({value} > {CurrencyConstants.MAX_CURRENCY})`
		end
	end
	return true
end

-- Registers the "currency" profile slice and returns typed read/mutate access. This is the shared
-- slice-owner scaffolding (see SliceOwner) — the currency VALUE type flows from the reader below, so
-- `currencySlice.get` returns `Currency?` and every `currencySlice.mutate` mutator argument is typed
-- `Currency`, with no casts. Only currency's DOMAIN logic (caps, arithmetic) lives in this file.
local currencySlice = SliceOwner.register("currency", {
	gold = 100,
	gems = 10,
}, function(profile)
	return profile.currency
end, validateCurrency)

local log = Logger.new("CurrencyServiceServer")

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	The module below is one annotated table literal. Annotating the literal makes Luau push each
	signature from this interface DOWN into the matching method body, so the methods need NO inline
	type annotations. Types live in exactly one place, and there are zero casts.

	Reads/writes go through `currencySlice` (SliceOwner) rather than PlayerDataService directly: the
	slice owns the "currency" path string and the type, so there is no stringly-typed path to typo and
	the mutator's `currency` argument is typed without an inline annotation.

	Writes reach the owning client through the reactive path only: a mutation updates the profile,
	`PlayerDataServiceServer:mutate` mirrors the slice into `ServerStore`, and charm-sync ships the
	delta. There is no per-write broadcast packet.
]=]
export type CurrencyServiceServer = {
	dependencies: { string },

	init: (self: CurrencyServiceServer) -> (),
	getCurrency: (self: CurrencyServiceServer, userId: number) -> PlayerDataTypes.Currency?,
	getCurrencyAmount: (
		self: CurrencyServiceServer,
		userId: number,
		currencyType: CurrencyConstants.CurrencyType
	) -> number,
	hasCurrency: (
		self: CurrencyServiceServer,
		userId: number,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number
	) -> boolean,
	addCurrency: (
		self: CurrencyServiceServer,
		userId: number,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number
	) -> boolean,
	removeCurrency: (
		self: CurrencyServiceServer,
		userId: number,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number
	) -> boolean,
	setCurrency: (
		self: CurrencyServiceServer,
		userId: number,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number
	) -> boolean,
	currencyOp: (
		self: CurrencyServiceServer,
		userId: number,
		mutator: (currency: PlayerDataTypes.Currency) -> boolean
	) -> PlayerDataService.TransactionOperation,
	getState: (self: CurrencyServiceServer) -> { [string]: any },
}

local CurrencyServiceServer: CurrencyServiceServer = {
	dependencies = { "PlayerDataServiceServer" },

	--[=[
		Initializes the CurrencyServiceServer. Validates the hand-maintained CurrencyType union
		against the CURRENCIES table (see docs/limitations.md #1) so a drift fails loudly at boot
		rather than at first use.
		@param self CurrencyServiceServer -- The service instance
	]=]
	init = function(_self)
		CurrencyConstants.validateCurrencyTypes()
		log:debug("CurrencyServiceServer initialized")
	end,

	--[=[
		Gets the currency data for a specified user.
		@param userId number -- The user ID to get currency for
		@return PlayerDataTypes.Currency? -- The currency data or nil if not found
	]=]
	getCurrency = function(_self, userId)
		return currencySlice.get(userId)
	end,

	--[=[
		Gets a specific currency amount for a user.
		@param userId number -- The user ID
		@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gold", etc.)
		@return number -- The amount of that currency
	]=]
	getCurrencyAmount = function(self, userId, currencyType)
		Guard.userId(userId)
		assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)

		return CurrencyUtils.getCurrencyAmount(self:getCurrency(userId), currencyType)
	end,

	--[=[
		Checks if a player has enough of a specific currency.
		@param userId number -- The user ID
		@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gold", etc.)
		@param amount number -- The amount to check for
		@return boolean -- True if the player has enough, false otherwise
	]=]
	hasCurrency = function(self, userId, currencyType, amount)
		Guard.userId(userId)
		assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
		Guard.positiveAmount(amount)

		return CurrencyUtils.hasEnoughCurrency(self:getCurrency(userId), currencyType, amount)
	end,

	--[=[
		Adds currency to a player's account.
		@param userId number -- The user ID
		@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gold", etc.)
		@param amount number -- The amount to add
		@return boolean -- True if successful, false otherwise
	]=]
	addCurrency = function(_self, userId, currencyType, amount)
		Guard.userId(userId)
		assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
		Guard.positiveAmount(amount)

		return currencySlice.mutate(userId, function(currency)
			local oldAmount = currency[currencyType] or 0
			local newAmount = math.min(oldAmount + amount, CurrencyConstants.MAX_CURRENCY)
			if newAmount == oldAmount then
				return false -- No change due to cap
			end
			currency[currencyType] = newAmount
			return true
		end)
	end,

	--[=[
		Removes currency from a player's account.
		@param userId number -- The user ID
		@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gold", etc.)
		@param amount number -- The amount to remove
		@return boolean -- True if successful, false otherwise
	]=]
	removeCurrency = function(_self, userId, currencyType, amount)
		Guard.userId(userId)
		assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
		Guard.positiveAmount(amount)

		return currencySlice.mutate(userId, function(currency)
			local oldAmount = currency[currencyType] or 0
			if oldAmount < amount then
				return false
			end
			currency[currencyType] = oldAmount - amount
			return true
		end)
	end,

	--[=[
		Sets a specific currency amount for a player. The amount is clamped to MAX_CURRENCY so the cap
		invariant holds for every write path — matching addCurrency, which also caps.
		@param userId number -- The user ID
		@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gold", etc.)
		@param amount number -- The amount to set (clamped to MAX_CURRENCY)
		@return boolean -- True if successful, false otherwise
	]=]
	setCurrency = function(_self, userId, currencyType, amount)
		Guard.userId(userId)
		assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
		Guard.nonNegativeAmount(amount)

		local clamped = math.min(amount, CurrencyConstants.MAX_CURRENCY)
		return currencySlice.mutate(userId, function(currency)
			local oldAmount = currency[currencyType] or 0
			if oldAmount == clamped then
				return false -- No change needed
			end
			currency[currencyType] = clamped
			return true
		end)
	end,

	--[=[
		Mints a typed TransactionOperation over the currency slice, for composing multi-slice /
		multi-player atomic writes via `PlayerDataService:transaction()`. The mutator's `currency`
		param is fully typed — this is the typed alternative to hand-writing a raw operation table.
		Pure packaging: nothing runs (and no validation beyond userId) until transaction() executes.

		```lua
		PlayerDataService:transaction({
			CurrencyService:currencyOp(sellerId, function(c) c.gold += 500 return true end),
			CurrencyService:currencyOp(buyerId, function(c)
				if c.gold < 500 then return false end
				c.gold -= 500 return true
			end),
		})
		```
		@param userId number -- The user ID the op targets
		@param mutator (currency: Currency) -> boolean -- Typed mutator; return false to abort the transaction
		@return PlayerDataService.TransactionOperation
	]=]
	currencyOp = function(_self, userId, mutator)
		return currencySlice.op(userId, mutator)
	end,

	--[=[
		Returns the current state of the service for debugging.
		@return { [string]: any } -- Service state
	]=]
	getState = function(_self)
		return {
			note = "Currency data is stored in PlayerDataServiceServer profiles. Use PlayerDataServiceServer:getState() to inspect.",
		}
	end,
}

return CurrencyServiceServer
