--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local CurrencyUtils = require(ReplicatedStorage.Shared.Features.Currency.Utils.CurrencyUtils)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)

-- Registers "currency" as a SLOT-SCOPED slice: each character has its own balance. The reader takes a
-- PlayerSlot (not a whole profile), which is what lets PlayerDataSliceSystem serve both `get` (the active
-- character) and `getForSlot` (the slot-select preview) from one typed closure. Currency's DOMAIN
-- logic below is unchanged — the service never learns that slots exist.
--
-- The currency invariant (registered key, non-negative, <= MAX_CURRENCY) is enforced by the DATA LAYER
-- on EVERY write via CurrencyUtils.validateCurrency — shared with the bank's `currency` (see the bank
-- design spec), so a raw op can never persist an unknown key or an out-of-range balance on either.
local currencySlice = PlayerDataSliceSystem.registerSlot("currency", {
	gloom = 0,
	credits = 0,
}, function(slot)
	return slot.currency
end, CurrencyUtils.validateCurrency)

local log = Logger.new("CurrencyServiceServer")

local currencyChanged: SignalTyped.Signal<CurrencyConstants.CurrencyChange> = SignalTyped.new()

-- Fires one change event for a balance that moved (nothing when it did not). Always called AFTER
-- `mutate` returns, never inside the mutator (a no-yield region).
local function report(
	userId: number,
	currency: CurrencyConstants.CurrencyType,
	oldAmount: number,
	newAmount: number,
	reason: CurrencyConstants.ChangeReason
)
	if newAmount == oldAmount then
		return
	end
	currencyChanged:Fire({
		userId = userId,
		currency = currency,
		flow = if newAmount > oldAmount then "source" else "sink",
		amount = math.abs(newAmount - oldAmount),
		balance = newAmount,
		reason = reason,
	})
end

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	The module below is one annotated table literal. Annotating the literal makes Luau push each
	signature from this interface DOWN into the matching method body, so the methods need NO inline
	type annotations. Types live in exactly one place, and there are zero casts.

	Reads/writes go through `currencySlice` (PlayerDataSliceSystem) rather than PlayerDataService directly: the
	slice owns the "currency" path string and the type, so there is no stringly-typed path to typo and
	the mutator's `currency` argument is typed without an inline annotation.

	Writes reach the owning client through the reactive path only: a mutation updates the profile,
	`PlayerDataServiceServer:mutate` mirrors the slice into `StateSyncServerStore`, and charm-sync ships the
	delta. There is no per-write broadcast packet.
]=]
export type CurrencyServiceServer = {
	dependencies: { string },
	changed: SignalTyped.Signal<CurrencyConstants.CurrencyChange>,

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
		amount: number,
		reason: CurrencyConstants.ChangeReason?
	) -> boolean,
	removeCurrency: (
		self: CurrencyServiceServer,
		userId: number,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number,
		reason: CurrencyConstants.ChangeReason?
	) -> boolean,
	setCurrency: (
		self: CurrencyServiceServer,
		userId: number,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number,
		reason: CurrencyConstants.ChangeReason?
	) -> boolean,
	grant: (
		self: CurrencyServiceServer,
		userId: number,
		amounts: CurrencyConstants.Amounts,
		reason: CurrencyConstants.ChangeReason
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
	changed = currencyChanged,

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
		@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gloom" or "credits")
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
		@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gloom" or "credits")
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
		@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gloom" or "credits")
		@param amount number -- The amount to add
		@return boolean -- True if successful, false otherwise
	]=]
	addCurrency = function(_self, userId, currencyType, amount, reason)
		Guard.userId(userId)
		assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
		Guard.positiveAmount(amount)

		-- Truncate mutate's (changed, reason) to the declared boolean: Currency doesn't surface
		-- validator reasons yet (see Inventory/Equipment for the surfaced pattern when it does).
		local before, after = 0, 0
		local changed = currencySlice.mutate(userId, function(currency)
			local oldAmount = currency[currencyType] or 0
			local newAmount = math.min(oldAmount + amount, CurrencyConstants.MAX_CURRENCY)
			if newAmount == oldAmount then
				return false -- No change due to cap
			end
			before, after = oldAmount, newAmount
			currency[currencyType] = newAmount
			return true
		end)
		if changed then
			report(userId, currencyType, before, after, reason or "other")
		end
		return changed
	end,

	--[=[
		Removes currency from a player's account.
		@param userId number -- The user ID
		@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gloom" or "credits")
		@param amount number -- The amount to remove
		@return boolean -- True if successful, false otherwise
	]=]
	removeCurrency = function(_self, userId, currencyType, amount, reason)
		Guard.userId(userId)
		assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
		Guard.positiveAmount(amount)

		-- Truncate mutate's (changed, reason) to the declared boolean: Currency doesn't surface
		-- validator reasons yet (see Inventory/Equipment for the surfaced pattern when it does).
		local before, after = 0, 0
		local changed = currencySlice.mutate(userId, function(currency)
			local oldAmount = currency[currencyType] or 0
			if oldAmount < amount then
				return false
			end
			before, after = oldAmount, oldAmount - amount
			currency[currencyType] = after
			return true
		end)
		if changed then
			report(userId, currencyType, before, after, reason or "other")
		end
		return changed
	end,

	--[=[
		Sets a specific currency amount for a player. The amount is clamped to MAX_CURRENCY so the cap
		invariant holds for every write path — matching addCurrency, which also caps.
		@param userId number -- The user ID
		@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gloom" or "credits")
		@param amount number -- The amount to set (clamped to MAX_CURRENCY)
		@return boolean -- True if successful, false otherwise
	]=]
	setCurrency = function(_self, userId, currencyType, amount, reason)
		Guard.userId(userId)
		assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
		Guard.nonNegativeAmount(amount)

		local clamped = math.min(amount, CurrencyConstants.MAX_CURRENCY)
		-- Truncate mutate's (changed, reason) to the declared boolean: Currency doesn't surface
		-- validator reasons yet (see Inventory/Equipment for the surfaced pattern when it does).
		local before = 0
		local changed = currencySlice.mutate(userId, function(currency)
			local oldAmount = currency[currencyType] or 0
			if oldAmount == clamped then
				return false -- No change needed
			end
			before = oldAmount
			currency[currencyType] = clamped
			return true
		end)
		if changed then
			report(userId, currencyType, before, clamped, reason or "other")
		end
		return changed
	end,

	--[=[
		Credits several currencies in ONE write (one currency-slice mutation), each capped at MAX_CURRENCY. Server-only
		reward path (shift pay). Zero amounts are skipped; an unknown currency key or a negative/non-finite amount throws
		before anything is written. Fires `changed` once per currency whose balance moved, after the write.
		@param userId number -- The user ID
		@param amounts CurrencyConstants.Amounts -- Amount to add per currency
		@param reason CurrencyConstants.ChangeReason -- Why, for economy analytics
		@return boolean -- True when at least one balance changed (false: nothing to add, everything already at the cap, or no profile)
	]=]
	grant = function(_self, userId, amounts, reason)
		Guard.userId(userId)
		local adds: { { currency: CurrencyConstants.CurrencyType, amount: number } } = {}
		for key, amount in amounts do
			assert(CurrencyConstants.isValidCurrencyType(key), `invalid currency type: "{key}"`)
			Guard.nonNegativeAmount(amount)
		end
		for _, currencyType: CurrencyConstants.CurrencyType in CurrencyConstants.getValidCurrencies() do
			local amount = amounts[currencyType]
			if amount ~= nil and amount > 0 then
				table.insert(adds, { currency = currencyType, amount = amount })
			end
		end
		if #adds == 0 then
			return false
		end

		local moved: { { currency: CurrencyConstants.CurrencyType, before: number, after: number } } = {}
		local changed = currencySlice.mutate(userId, function(currency)
			table.clear(moved) -- a re-run mutator must not double-report
			for _, add in adds do
				local oldAmount = currency[add.currency] or 0
				local newAmount = math.min(oldAmount + add.amount, CurrencyConstants.MAX_CURRENCY)
				if newAmount ~= oldAmount then
					currency[add.currency] = newAmount
					table.insert(moved, { currency = add.currency, before = oldAmount, after = newAmount })
				end
			end
			return #moved > 0
		end)
		if changed then
			for _, move in moved do
				report(userId, move.currency, move.before, move.after, reason)
			end
		end
		return changed
	end,

	--[=[
		Mints a typed TransactionOperation over the currency slice, for composing multi-slice /
		multi-player atomic writes via `PlayerDataService:transaction()`. The mutator's `currency`
		param is fully typed — this is the typed alternative to hand-writing a raw operation table.
		Pure packaging: nothing runs (and no validation beyond userId) until transaction() executes.
		Raw transaction ops do NOT fire `changed`; use `grant` for reportable payouts.

		```lua
		PlayerDataService:transaction({
			CurrencyService:currencyOp(sellerId, function(c) c.credits += 500 return true end),
			CurrencyService:currencyOp(buyerId, function(c)
				if c.credits < 500 then return false end
				c.credits -= 500 return true
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
