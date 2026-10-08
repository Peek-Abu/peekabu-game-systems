--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local BankEvents = require(ReplicatedStorage.Shared.Features.Bank.Net.BankEvents)

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	A read facade over `StateSyncClientStore.bank`, the one client source of truth (populated by charm-sync from
	the ACTIVE character's bank), plus the four transfer REQUESTS. Same shape as
	InventoryServiceClient/EquipmentServiceClient: reactive UI reads the atom directly via `useAtom`;
	imperative callers use the point-in-time accessor.

	The writes are requests, not writes: nothing here touches the store. The server owns the move, and
	the result comes back through charm-sync into `StateSyncClientStore.bank` and `StateSyncClientStore.inventory`, which
	the screen already reads reactively. Predicting the outcome locally would create a second source of
	truth for the same state — and a transfer can be refused (either container full, item gone), so the
	prediction would sometimes be wrong.

	Items address a unique instance by `uid` or a stackable's WHOLE holding by `itemType` — separate
	methods rather than one taking a union, matching the packets and, through them, the server (see
	BankEvents). There is no partial-quantity item transfer; currency is the only thing carrying an
	amount.
]=]
export type BankServiceClient = {
	dependencies: { string },

	getBank: (self: BankServiceClient) -> PlayerDataTypes.Bank,

	depositUnique: (self: BankServiceClient, uid: string) -> (),
	withdrawUnique: (self: BankServiceClient, uid: string) -> (),
	depositStack: (self: BankServiceClient, itemType: string) -> (),
	withdrawStack: (self: BankServiceClient, itemType: string) -> (),

	depositCurrency: (
		self: BankServiceClient,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number
	) -> (),
	withdrawCurrency: (
		self: BankServiceClient,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number
	) -> (),
}

local BankServiceClient: BankServiceClient = {
	dependencies = {},

	--[=[
		Gets the local player's bank from the reactive store (empty items/currency until the first sync).
		@return PlayerDataTypes.Bank
	]=]
	getBank = function(_self)
		return StateSyncClientStore.bank()
	end,

	--[=[
		Asks the server to move one unique item from the bag into the bank. Fire and forget (see header).
		@param uid string -- The UID of the instance to move
	]=]
	depositUnique = function(_self, uid)
		BankEvents.packets.DepositUnique.send(uid)
	end,

	--[=[
		Asks the server to move one unique item from the bank back into the bag.
		@param uid string -- The UID of the instance to move
	]=]
	withdrawUnique = function(_self, uid)
		BankEvents.packets.WithdrawUnique.send(uid)
	end,

	--[=[
		Asks the server to move a stackable's WHOLE held quantity from the bag into the bank. There is no
		partial transfer — the server moves every stack of the itemType at once (bank design Decision 4).
		@param itemType string
	]=]
	depositStack = function(_self, itemType)
		BankEvents.packets.DepositStack.send(itemType)
	end,

	--[=[
		The inverse of depositStack: the whole holding, bank → bag.
		@param itemType string
	]=]
	withdrawStack = function(_self, itemType)
		BankEvents.packets.WithdrawStack.send(itemType)
	end,

	--[=[
		Asks the server to move currency into the bank. "Deposit all" is this with the full balance, not a
		separate verb, so the server has exactly one currency path to reason about.
		@param currencyType CurrencyConstants.CurrencyType
		@param amount number -- must be positive; the packet's uint32 cannot carry a negative
	]=]
	depositCurrency = function(_self, currencyType, amount)
		BankEvents.packets.DepositCurrency.send({ currency = currencyType, amount = amount })
	end,

	--[=[
		The inverse of depositCurrency: bank → the character's purse.
		@param currencyType CurrencyConstants.CurrencyType
		@param amount number -- must be positive
	]=]
	withdrawCurrency = function(_self, currencyType, amount)
		BankEvents.packets.WithdrawCurrency.send({ currency = currencyType, amount = amount })
	end,
}

return BankServiceClient
