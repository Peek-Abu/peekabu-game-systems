--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local InventoryShared = ReplicatedStorage.Shared.Features.Inventory
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)
local InventoryUtils = require(InventoryShared.Utils.InventoryUtils)
local CurrencyUtils = require(ReplicatedStorage.Shared.Features.Currency.Utils.CurrencyUtils)
local InventoryContainerRules = require(InventoryShared.Rules.InventoryContainerRules)
local InventoryPlacementUtils = require(InventoryShared.Utils.InventoryPlacementUtils)
local BankConstants = require(ReplicatedStorage.Shared.Features.Bank.Data.BankConstants)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local BankReceiver = require(ServerScriptService.Features.Bank.Net.BankReceiver)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local CurrencyServiceServer = require(ServerScriptService.Features.Currency.CurrencyServiceServer)

--[=[
	The bank invariant, enforced by the DATA LAYER on every write. Items reuse the SHARED
	`InventoryContainerRules.checkEntryShapes` (identical entry rules to Inventory, incl. Phase 3c modifier
	maps); the ONE thing that differs is the capacity policy — Bank is a flat TOTAL-entry cap (a stash
	is one pool, not kind-partitioned). Currency reuses the SAME `CurrencyUtils.validateCurrency` a
	slot's currency uses. See the bank design spec.
]=]
local function validateBank(bank: PlayerDataTypes.Bank): (boolean, string?)
	if type(bank) ~= "table" then
		return false, `bank must be a table, got {type(bank)}`
	end

	local ok, reason, result = InventoryContainerRules.checkEntryShapes(bank.items, "bank")
	if not ok then
		return false, reason
	end
	assert(result, "checkEntryShapes returns counts on success")
	local total = 0
	for _, count in result.kindCounts do
		total += count
	end
	if total > BankConstants.CAPACITY then
		return false, `bank holds {total} entries, exceeding CAPACITY ({BankConstants.CAPACITY})`
	end

	if type(bank.currency) ~= "table" then
		return false, `bank.currency must be a table, got {type(bank.currency)}`
	end
	return CurrencyUtils.validateCurrency(bank.currency)
end

-- Registers "bank" as a SLOT-SCOPED slice: each character has its own bank (Decision 1). Same
-- slot-scoping as inventory/equipment/currency.
local bankSlice = PlayerDataSliceSystem.registerSlot("bank", { items = {}, currency = {} }, function(slot)
	return slot.bank
end, validateBank)

local log = Logger.new("BankServiceServer")

local janitor = Janitor.new()

-- Forward-declared: it closes over the service table, which is not in scope inside its own initializer.
-- Assigned below the table, the same way EquipmentServiceServer's packet handlers are.
local bindRequests: () -> ()

-- BANK's entry-capacity policy for InventoryPlacementUtils: a FLAT total-entry cap, kind-agnostic (Inventory
-- injects a per-kind check instead — see InventoryServiceServer.roomCheck).
local function bankHasRoom(
	items: { PlayerDataTypes.InventoryEntry },
	_kind: string,
	newEntriesNeeded: number
): (boolean, string?)
	local total = #items
	if total + newEntriesNeeded > BankConstants.CAPACITY then
		return false,
			`bank would hold {total + newEntriesNeeded} entries, exceeding CAPACITY ({BankConstants.CAPACITY})`
	end
	return true
end

-- Op-builders that hand a mutator the container's ITEMS array directly, so the direction-agnostic
-- transfer helpers below don't care which slice (inventory wrapper vs bank) they are moving between.
type ItemsOpBuilder = (
	userId: number,
	fn: (items: { PlayerDataTypes.InventoryEntry }) -> boolean
) -> PlayerDataService.TransactionOperation
type CurrencyOpBuilder = (
	userId: number,
	fn: (currency: PlayerDataTypes.Currency) -> boolean
) -> PlayerDataService.TransactionOperation

local function invItemsOp(userId: number, fn: (items: { PlayerDataTypes.InventoryEntry }) -> boolean)
	return InventoryServiceServer:inventoryOp(userId, function(inventory)
		return fn(inventory.items)
	end)
end
local function bankItemsOp(userId: number, fn: (items: { PlayerDataTypes.InventoryEntry }) -> boolean)
	return bankSlice.op(userId, function(bank)
		return fn(bank.items)
	end)
end
local function slotCurrencyOp(userId: number, fn: (currency: PlayerDataTypes.Currency) -> boolean)
	return CurrencyServiceServer:currencyOp(userId, fn)
end
local function bankCurrencyOp(userId: number, fn: (currency: PlayerDataTypes.Currency) -> boolean)
	return bankSlice.op(userId, function(bank)
		return fn(bank.currency)
	end)
end

-- Removes every stack entry of `itemType`, returning the total quantity removed (0 if none held).
local function removeAllStacksOf(items: { PlayerDataTypes.InventoryEntry }, itemType: string): number
	local total = 0
	for i = #items, 1, -1 do
		local entry = items[i]
		if entry.itemType == itemType then
			total += (entry :: PlayerDataTypes.StackEntry).quantity -- caller passes a stackable itemType → StackEntry
			table.remove(items, i)
		end
	end
	return total
end

-- Applies a merge-then-spill placement plan (top up existing stacks + open new ones) to `items`.
local function applyStackPlan(
	items: { PlayerDataTypes.InventoryEntry },
	itemType: string,
	plan: InventoryPlacementUtils.StackPlacement
)
	local updates = plan.updates
	assert(updates, "a feasible plan carries updates")
	for index, newQuantity in updates do
		local stack = items[index] :: PlayerDataTypes.StackEntry -- plan update-index is a same-itemType stack
		stack.quantity = newQuantity
	end
	local newStacks = plan.newStacks
	assert(newStacks, "a feasible plan carries newStacks")
	for _, quantity in newStacks do
		table.insert(items, { itemType = itemType, quantity = quantity })
	end
end

local function reasonFrom(ok: boolean, result: PlayerDataService.TransactionResult, captured: string?): string?
	if ok then
		return nil
	end
	return captured or result.rejectionReason or "bank transfer rejected (see server logs)"
end

-- Atomic move of ONE unique entry (by uid) between two item containers. The DEST's registered
-- validator backstops its capacity (a unique is a single entry).
local function moveUnique(userId: number, uid: string, fromOp: ItemsOpBuilder, toOp: ItemsOpBuilder): (boolean, string?)
	local moved: PlayerDataTypes.UniqueEntry? = nil
	local captured: string? = nil
	local ok, result = PlayerDataService:transaction({
		fromOp(userId, function(items)
			local index, entry = InventoryUtils.findByUid({ items = items }, uid)
			if not index then
				captured = `no item with uid "{uid}" in the source container`
				return false
			end
			moved = entry
			table.remove(items, index)
			return true
		end),
		toOp(userId, function(items)
			assert(moved, "the from-op above captured the moved entry")
			table.insert(items, moved)
			return true
		end),
	})
	return ok, reasonFrom(ok, result, captured)
end

-- Atomic move of the WHOLE held quantity of a stackable itemType between two containers: remove every
-- source stack, then merge-then-spill the total into the dest via the dest's room policy.
local function moveStackable(
	userId: number,
	itemType: string,
	definition: PlayerDataTypes.ItemDefinition,
	fromOp: ItemsOpBuilder,
	toOp: ItemsOpBuilder,
	toRoom: InventoryPlacementUtils.RoomCheck
): (boolean, string?)
	local stackMax, maxStacks = InventoryContainerRules.stackLimitsOf(definition)
	local total = 0
	local captured: string? = nil
	local ok, result = PlayerDataService:transaction({
		fromOp(userId, function(items)
			total = removeAllStacksOf(items, itemType)
			if total <= 0 then
				captured = `no "{itemType}" in the source container`
				return false
			end
			return true
		end),
		toOp(userId, function(items)
			local plan = InventoryPlacementUtils.planStackPlacement(
				items,
				itemType,
				total,
				stackMax,
				maxStacks,
				definition.kind,
				toRoom
			)
			if not plan.ok then
				captured = plan.reason
				return false
			end
			applyStackPlan(items, itemType, plan)
			return true
		end),
	})
	return ok, reasonFrom(ok, result, captured)
end

-- Dispatches a whole-holding item move (unique-by-uid or stackable-by-itemType) in a given direction.
local function transferItem(
	userId: number,
	spec: { uid: string } | { itemType: string },
	fromOp: ItemsOpBuilder,
	toOp: ItemsOpBuilder,
	toRoom: InventoryPlacementUtils.RoomCheck
): (boolean, string?)
	assert(type(spec) == "table", `spec must be a table, got {type(spec)}`)
	-- Same-union-member cast to discriminate (validateInventory/removeItem use this exact pattern).
	local asUid = spec :: { uid: string } -- narrow to the uid arm of spec's own union, then check at runtime
	if asUid.uid ~= nil then
		assert(type(asUid.uid) == "string" and asUid.uid ~= "", "uid must be a non-empty string")
		return moveUnique(userId, asUid.uid, fromOp, toOp)
	end

	local itemType = (spec :: { itemType: string }).itemType -- narrow to the itemType arm of spec's own union
	assert(type(itemType) == "string" and itemType ~= "", "itemType must be a non-empty string")
	if not ItemRegistry.isValidItemType(itemType) then
		return false, `"{itemType}" is not a registered item type`
	end
	if not ItemRegistry.isStackable(itemType) then
		return false, `"{itemType}" is unique — move it by uid, not itemType`
	end
	local definition = ItemRegistry.get(itemType)
	assert(definition, "isValidItemType proved registration")
	return moveStackable(userId, itemType, definition, fromOp, toOp, toRoom)
end

-- Atomic move of `amount` of a currency between two currency containers. Source refuses on insufficient
-- balance; dest refuses on a MAX_CURRENCY breach (the validator backstops both regardless).
local function transferCurrency(
	userId: number,
	currencyType: CurrencyConstants.CurrencyType,
	amount: number,
	fromOp: CurrencyOpBuilder,
	toOp: CurrencyOpBuilder
): (boolean, string?)
	local captured: string? = nil
	local ok, result = PlayerDataService:transaction({
		fromOp(userId, function(currency)
			local held = currency[currencyType] or 0
			if held < amount then
				captured = `insufficient {currencyType} ({held} < {amount})`
				return false
			end
			currency[currencyType] = held - amount
			return true
		end),
		toOp(userId, function(currency)
			local held = currency[currencyType] or 0
			if held + amount > CurrencyConstants.MAX_CURRENCY then
				captured =
					`{currencyType} would exceed MAX_CURRENCY ({held + amount} > {CurrencyConstants.MAX_CURRENCY})`
				return false
			end
			currency[currencyType] = held + amount
			return true
		end),
	})
	return ok, reasonFrom(ok, result, captured)
end

--[=[
	Public interface — the SINGLE place method/field types are declared (lean annotated-literal shape,
	mirroring Inventory/Equipment). Deposit/withdraw are atomic 2-op transactions between the bank slice
	and the inventory/currency slices, the same container-move pattern equip/unequip uses.
]=]
export type BankServiceServer = {
	dependencies: { string },

	getBank: (self: BankServiceServer, userId: number) -> PlayerDataTypes.Bank?,
	depositItem: (
		self: BankServiceServer,
		userId: number,
		spec: { uid: string } | { itemType: string }
	) -> (boolean, string?),
	withdrawItem: (
		self: BankServiceServer,
		userId: number,
		spec: { uid: string } | { itemType: string }
	) -> (boolean, string?),
	depositCurrency: (
		self: BankServiceServer,
		userId: number,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number
	) -> (boolean, string?),
	withdrawCurrency: (
		self: BankServiceServer,
		userId: number,
		currencyType: CurrencyConstants.CurrencyType,
		amount: number
	) -> (boolean, string?),
	bankOp: (
		self: BankServiceServer,
		userId: number,
		fn: (bank: PlayerDataTypes.Bank) -> boolean
	) -> PlayerDataService.TransactionOperation,
	init: (self: BankServiceServer) -> (),
	stop: (self: BankServiceServer) -> (),
	getState: (self: BankServiceServer) -> { [string]: any },
}

local BankServiceServer: BankServiceServer = {
	dependencies = { "PlayerDataServiceServer", "InventoryServiceServer", "CurrencyServiceServer" },

	--[=[
		Gets the bank wrapper for a user's ACTIVE character, or nil if the profile is not loaded.
		@param userId number -- The user ID
		@return PlayerDataTypes.Bank?
	]=]
	getBank = function(_self, userId)
		return bankSlice.get(userId)
	end,

	--[=[
		Moves an item from the active inventory INTO the bank, all-or-nothing. `spec` is `{ uid }` for a
		specific unique instance, or `{ itemType }` to move the WHOLE held quantity of a stackable.
		@param userId number
		@param spec { uid: string } | { itemType: string }
		@return boolean, string? -- (ok, reason-on-failure)
	]=]
	depositItem = function(_self, userId, spec)
		Guard.userId(userId)
		if not PlayerDataService:getActiveSlot(userId) then
			return false, `no profile loaded for userId {userId}`
		end
		local ok, reason = transferItem(userId, spec, invItemsOp, bankItemsOp, bankHasRoom)
		if not ok then
			log:warn(`depositItem refused for userId {userId}:`, reason)
		end
		return ok, reason
	end,

	--[=[
		The inverse of depositItem: bank → inventory. Re-enters through inventory's own registered
		validator, so a withdrawal that would breach inventory's per-kind cap is refused automatically.
		@param userId number
		@param spec { uid: string } | { itemType: string }
		@return boolean, string?
	]=]
	withdrawItem = function(_self, userId, spec)
		Guard.userId(userId)
		if not PlayerDataService:getActiveSlot(userId) then
			return false, `no profile loaded for userId {userId}`
		end
		local ok, reason = transferItem(userId, spec, bankItemsOp, invItemsOp, InventoryServiceServer.roomCheck)
		if not ok then
			log:warn(`withdrawItem refused for userId {userId}:`, reason)
		end
		return ok, reason
	end,

	--[=[
		Moves `amount` of a currency from the active slot's balance INTO the bank, all-or-nothing.
		@param userId number
		@param currencyType CurrencyConstants.CurrencyType
		@param amount number -- positive
		@return boolean, string?
	]=]
	depositCurrency = function(_self, userId, currencyType, amount)
		Guard.userId(userId)
		assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
		Guard.positiveAmount(amount)
		if not PlayerDataService:getActiveSlot(userId) then
			return false, `no profile loaded for userId {userId}`
		end
		return transferCurrency(userId, currencyType, amount, slotCurrencyOp, bankCurrencyOp)
	end,

	--[=[
		The inverse of depositCurrency: bank → active slot balance.
		@param userId number
		@param currencyType CurrencyConstants.CurrencyType
		@param amount number -- positive
		@return boolean, string?
	]=]
	withdrawCurrency = function(_self, userId, currencyType, amount)
		Guard.userId(userId)
		assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
		Guard.positiveAmount(amount)
		if not PlayerDataService:getActiveSlot(userId) then
			return false, `no profile loaded for userId {userId}`
		end
		return transferCurrency(userId, currencyType, amount, bankCurrencyOp, slotCurrencyOp)
	end,

	--[=[
		Mints a typed TransactionOperation over the bank slice, for composing multi-slice atomic writes.
		Pure packaging — the mutator does not run until transaction() executes.
		@param userId number
		@param fn (bank: Bank) -> boolean -- return false to abort
		@return PlayerDataService.TransactionOperation
	]=]
	bankOp = function(_self, userId, fn)
		return bankSlice.op(userId, fn)
	end,

	--[=[
		Wires the transfer packet listeners. The rules stay in depositItem/withdrawItem, which the Cmdr
		commands call too, so the two entry points cannot disagree about what is legal; RequestHandler
		adds the rate limit and isolates a throwing handler.
		@param self BankServiceServer -- The service instance
	]=]
	init = function(_self)
		bindRequests()
	end,

	--[=[
		Drops the packet listeners.
		@param self BankServiceServer -- The service instance
	]=]
	stop = function(_self)
		janitor:Cleanup()
	end,

	--[=[
		Debugger state. Bank data lives in PlayerDataServiceServer profiles (inspect there / via the
		"bank" mirror in the State panel); this reports only the flat capacity tuning.
		@return { [string]: any }
	]=]
	getState = function(_self)
		return { capacity = BankConstants.CAPACITY }
	end,
}

-- The packet layer is handed the transfer METHODS, not the service, so it never reaches back into a
-- module that is still being defined, and nothing about the rules leaks out of here.
bindRequests = function()
	BankReceiver.bind(janitor, {
		depositItem = function(userId, spec)
			return BankServiceServer:depositItem(userId, spec)
		end,
		withdrawItem = function(userId, spec)
			return BankServiceServer:withdrawItem(userId, spec)
		end,
		depositCurrency = function(userId, currencyType, amount)
			return BankServiceServer:depositCurrency(userId, currencyType, amount)
		end,
		withdrawCurrency = function(userId, currencyType, amount)
			return BankServiceServer:withdrawCurrency(userId, currencyType, amount)
		end,
	})
end

return BankServiceServer
