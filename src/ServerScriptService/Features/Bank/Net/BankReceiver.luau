--!strict
--[=[
	BankReceiver: the packet layer in front of `BankServiceServer` — rate limiting, argument narrowing,
	and turning six packets into the service's four transfer methods.

	Split out of the service because it is a different job. The service owns the RULES (ownership,
	capacity, stackability, atomicity); this owns only what it takes to accept a request from an
	untrusted client and hand it over. Nothing here decides whether a transfer is legal — if it did, the
	packet path and the Cmdr commands could disagree about what is legal, which is exactly the drift this
	port exists to remove.

	It takes the transfer functions rather than requiring the service, so there is no require cycle and
	no reaching back into a module that is mid-definition.

	**Why six packets become four methods.** The server addresses an item as `{ uid }` or `{ itemType }`.
	The client never sends that shape: it sends one bare string on a packet whose NAME says which kind it
	is, and the union is built here. A malformed spec is therefore not expressible rather than expressible
	and rejected — the same reasoning that keeps the slot out of `EquipItem`.

	@class BankReceiver
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local BankEvents = require(ReplicatedStorage.Shared.Features.Bank.Net.BankEvents)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)

local log = Logger.new("BankReceiver")

-- A transfer is one click, and no surface offers a way to fire them faster. Matches the equip limit:
-- both are "a player poking at their inventory", so one number to reason about rather than two that
-- drift apart.
--
-- The KEY is what makes that one number true. RequestHandler buckets per key, defaulting to the packet
-- name, and all six bank packets are the same player action — so keyed per name this was really six
-- independent budgets, and a client alternating between them went unlimited until 120 requests landed
-- in 5 seconds, each one a multi-slice PlayerDataService transaction.
local BANK_RATE_LIMIT = { maxRequests = 20, windowSeconds = 5 }
local BANK_RATE_LIMIT_KEY = "Bank"

--[=[
	Mirrors the currency packets' struct (see BankEvents), named once so the listener and the handler
	agree on one shape rather than restating it.
	@interface CurrencyTransfer
	.currency string -- validated against the registry here, never trusted
	.amount number
]=]
export type CurrencyTransfer = { currency: string, amount: number }

--[=[
	The service's transfer methods, as plain functions. Passed in rather than required, so this module
	does not depend on the service that wires it.
	@interface BankTransfers
	.depositItem (userId: number, spec) -> (boolean, string?)
	.withdrawItem (userId: number, spec) -> (boolean, string?)
	.depositCurrency (userId: number, currencyType, amount: number) -> (boolean, string?)
	.withdrawCurrency (userId: number, currencyType, amount: number) -> (boolean, string?)
]=]
export type BankTransfers = {
	depositItem: (userId: number, spec: { uid: string } | { itemType: string }) -> (boolean, string?),
	withdrawItem: (userId: number, spec: { uid: string } | { itemType: string }) -> (boolean, string?),
	depositCurrency: (
		userId: number,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number
	) -> (boolean, string?),
	withdrawCurrency: (
		userId: number,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number
	) -> (boolean, string?),
}

local BankReceiver = {}

--[=[
	Builds the handler for one item packet.

	A refusal is logged at DEBUG rather than as an error: a stale click on an item that has already moved
	lands here, and that is expected traffic, not a fault.
	@param name string -- the packet name, for the rate limiter and the log line
	@param transfer (userId: number, spec) -> (boolean, string?)
	@param asUid boolean -- true addresses a unique instance; false a stackable's whole holding
	@return (value: string, player: Player) -> ()
]=]
local function itemHandler(
	name: string,
	transfer: (userId: number, spec: { uid: string } | { itemType: string }) -> (boolean, string?),
	asUid: boolean
): (value: string, player: Player) -> any
	return RequestHandler.wrap({
		name = name,
		rateLimit = BANK_RATE_LIMIT,
		rateLimitKey = BANK_RATE_LIMIT_KEY,
		handler = function(value: string, player: Player)
			-- An empty string is a REFUSAL, not a fault. The service asserts a non-empty uid/itemType, and
			-- an empty string is not nil, so it reached that assert and raised — logged by RequestHandler
			-- at ERROR with a traceback, contradicting this module's own "a refusal is logged at DEBUG"
			-- contract and handing any client cheap ERROR-level log spam. Before these packets existed the
			-- asserts only ever saw Cmdr input from a developer; they are reachable from the wire now.
			if value == "" then
				log:debug(name, "refused for", player.Name, "- empty item spec")
				return
			end
			-- The union is built HERE, from which packet arrived, so the client never sends a shape.
			local spec: { uid: string } | { itemType: string } = if asUid then { uid = value } else { itemType = value }
			local ok, reason = transfer(player.UserId, spec)
			if not ok then
				log:debug(name, "refused for", player.Name, "-", reason)
			end
		end,
	})
end

--[=[
	Builds the handler for one currency packet.
	@param name string
	@param transfer (userId: number, currencyType, amount: number) -> (boolean, string?)
	@return (value: CurrencyTransfer, player: Player) -> ()
]=]
local function currencyHandler(
	name: string,
	transfer: (
		userId: number,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number
	) -> (boolean, string?)
): (value: CurrencyTransfer, player: Player) -> any
	return RequestHandler.wrap({
		name = name,
		rateLimit = BANK_RATE_LIMIT,
		rateLimitKey = BANK_RATE_LIMIT_KEY,
		handler = function(value: CurrencyTransfer, player: Player)
			-- The packet's uint32 cannot carry a negative, so zero is the only unusable value it can hold.
			if value.amount <= 0 then
				log:debug(name, "refused for", player.Name, "- amount must be positive")
				return
			end
			-- Narrowed, not cast: an unregistered currency name simply has no CurrencyType to become. The
			-- annotation is load-bearing — inferred, the singleton "jaku" widens back to `string` and the
			-- narrow buys nothing.
			local currencyType: CurrencyConstants.CurrencyType? = CurrencyConstants.toCurrencyType(value.currency)
			if currencyType == nil then
				log:debug(name, "refused for", player.Name, `- unknown currency "{value.currency}"`)
				return
			end
			local ok, reason = transfer(player.UserId, currencyType, value.amount)
			if not ok then
				log:debug(name, "refused for", player.Name, "-", reason)
			end
		end,
	})
end

--[=[
	Subscribes every bank packet, adding each connection to `janitor` so `stop` drops them all.

	The six blocks are written out rather than looped through a `listen(packet, handler)` helper: a local
	function is not generic in Luau, so the first call pins its parameter type and every later one is a
	type error. Six near-identical blocks is what it costs for the packets to stay typed.
	@param janitor Janitor.Janitor -- the service's janitor; owns the connections
	@param transfers BankTransfers -- the service's four transfer methods, as plain functions
]=]
function BankReceiver.bind(janitor: Janitor.Janitor, transfers: BankTransfers)
	local onDepositUnique = itemHandler("DepositUnique", transfers.depositItem, true)
	local onWithdrawUnique = itemHandler("WithdrawUnique", transfers.withdrawItem, true)
	local onDepositStack = itemHandler("DepositStack", transfers.depositItem, false)
	local onWithdrawStack = itemHandler("WithdrawStack", transfers.withdrawItem, false)
	local onDepositCurrency = currencyHandler("BankDepositCurrency", transfers.depositCurrency)
	local onWithdrawCurrency = currencyHandler("BankWithdrawCurrency", transfers.withdrawCurrency)

	-- ByteNet hands the server (data, player). A nil player means a malformed frame, not a request.
	janitor:Add(
		BankEvents.packets.DepositUnique.listen(function(uid: string, player: Player?)
			if player then
				onDepositUnique(uid, player)
			end
		end),
		true
	)
	janitor:Add(
		BankEvents.packets.WithdrawUnique.listen(function(uid: string, player: Player?)
			if player then
				onWithdrawUnique(uid, player)
			end
		end),
		true
	)
	janitor:Add(
		BankEvents.packets.DepositStack.listen(function(itemType: string, player: Player?)
			if player then
				onDepositStack(itemType, player)
			end
		end),
		true
	)
	janitor:Add(
		BankEvents.packets.WithdrawStack.listen(function(itemType: string, player: Player?)
			if player then
				onWithdrawStack(itemType, player)
			end
		end),
		true
	)
	janitor:Add(
		BankEvents.packets.DepositCurrency.listen(function(value: CurrencyTransfer, player: Player?)
			if player then
				onDepositCurrency(value, player)
			end
		end),
		true
	)
	janitor:Add(
		BankEvents.packets.WithdrawCurrency.listen(function(value: CurrencyTransfer, player: Player?)
			if player then
				onWithdrawCurrency(value, player)
			end
		end),
		true
	)
end

return BankReceiver
