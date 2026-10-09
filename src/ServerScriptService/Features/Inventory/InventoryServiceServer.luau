--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local InventoryShared = ReplicatedStorage.Shared.Features.Inventory
local ItemShared = ReplicatedStorage.Shared.Features.Item
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local InventoryUtils = require(InventoryShared.Utils.InventoryUtils)
local ItemRegistry = require(ItemShared.Data.ItemRegistry)
local InventoryContainerRules = require(InventoryShared.Rules.InventoryContainerRules)
local InventoryPlacementUtils = require(InventoryShared.Utils.InventoryPlacementUtils)
local ItemConstants = require(ItemShared.Data.ItemConstants)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)

-- Entry-shape checking and stack placement are shared with any second container a game adds via the
-- InventoryContainerRules / InventoryPlacementUtils modules. This service supplies only the INVENTORY cap
-- policy (per-kind KIND_CAPS), below.
local stackLimitsOf = InventoryContainerRules.stackLimitsOf

--[=[
	The inventory invariant, enforced by the DATA LAYER on every write (see PlayerDataSliceSystem's `validate`).
	The service methods below already respect it, but registering it here makes it hold for ANY path
	into the slice — including a raw `PlayerDataService:transaction()` op that never goes through
	addItem/removeItem. Runs after a mutator, inside the no-yield region, so it must stay
	pure/synchronous.

	Rules (see the item-definition-model spec):
	1. every `itemType` is registered;
	2. an entry's shape matches what `ItemRegistry.isStackable` says it should be — stackable:
	   integer `quantity` in `1..stackMax`, no `uid`; unique: non-empty string `uid`, no `quantity`;
	3. per-itemType STACK-entry count <= the def's `maxStacks`, when declared;
	4. per-kind entry count <= `ItemConstants.KIND_CAPS[kind]`;
	5. every `uid` in the array is unique.
]=]
local function validateInventory(inventory: PlayerDataTypes.Inventory): (boolean, string?)
	if type(inventory) ~= "table" then
		return false, `inventory must be a table, got {type(inventory)}`
	end

	-- Shared per-entry shape checks (registration, stack/unique shape, modifier maps, maxStacks) +
	-- per-kind counts — identical rules and messages, now sourced from InventoryContainerRules.
	local ok, reason, result = InventoryContainerRules.checkEntryShapes(inventory.items, "inventory")
	if not ok then
		return false, reason
	end
	assert(result, "checkEntryShapes returns counts on success")

	-- INVENTORY's own capacity policy: a per-KIND entry cap (another container may use a flat total cap instead).
	for kind, count in result.kindCounts do
		local cap = ItemConstants.KIND_CAPS[kind]
		if cap and count > cap then
			return false, `kind "{kind}" entry count {count} exceeds KIND_CAPS ({cap})`
		end
	end

	return true
end

--[=[
	The account-wide item-mint invariant: `nextUid` is a monotonic counter and must never regress or
	go non-integer. Enforced the same way as every other slice invariant — on the RESULT, after every
	mutator (including a raw op), not just on the increment path addItem happens to use.
]=]
local function validateItemMint(mint: PlayerDataTypes.ItemMint): (boolean, string?)
	if type(mint.nextUid) ~= "number" or mint.nextUid ~= math.floor(mint.nextUid) then
		return false, `nextUid must be an integer, got {tostring(mint.nextUid)}`
	end
	if mint.nextUid < 1 then
		return false, `nextUid must be >= 1, got {mint.nextUid}`
	end
	return true
end

-- Registers "inventory" as a SLOT-SCOPED slice: each character has its own inventory. The reader
-- takes a PlayerSlot (not a whole profile), which is what lets PlayerDataSliceSystem serve both `get` (the
-- active character) and `getForSlot` (the slot-select preview) from one typed closure.
local inventorySlice = PlayerDataSliceSystem.registerSlot("inventory", { items = {} }, function(slot)
	return slot.inventory
end, validateInventory)

-- Registers "itemMint" as an ACCOUNT-WIDE slice: the uid counter is shared by every character on the
-- account, so two characters minting concurrently can never collide (see PlayerDataTypes.ItemMint).
local itemMintSlice = PlayerDataSliceSystem.registerAccount("itemMint", { nextUid = 1 }, function(account)
	return account.itemMint
end, validateItemMint)

local log = Logger.new("InventoryServiceServer")

-- INVENTORY's room policy for InventoryPlacementUtils.planStackPlacement: the per-kind KIND_CAPS check
-- (another container injects its own policy, e.g. a flat total cap).
local function inventoryHasRoom(
	items: { PlayerDataTypes.InventoryEntry },
	kind: string,
	newEntriesNeeded: number
): (boolean, string?)
	local kindCap = ItemConstants.KIND_CAPS[kind]
	local kindEntries = InventoryUtils.countEntriesOfKind({ items = items }, kind)
	if kindCap and kindEntries + newEntriesNeeded > kindCap then
		return false,
			`kind "{kind}" would hold {kindEntries + newEntriesNeeded} entries, exceeding KIND_CAPS ({kindCap})`
	end
	return true
end

-- Adds `count` of a STACKABLE itemType in one mutate: merges into existing stacks up to stackMax,
-- then spills into new stacks (bounded by maxStacks and the kind cap). Feasibility is computed FIRST
-- inside the mutator (planStackPlacement never mutates `items`), so an infeasible add returns false
-- and writes nothing — the mutate rollback is defense in depth here, not the mechanism relied on.
local function addStackable(
	userId: number,
	itemType: string,
	definition: PlayerDataTypes.ItemDefinition,
	count: number
): (boolean, string?)
	-- Checked BEFORE mutating: inventorySlice.mutate returning false can mean either "no profile
	-- loaded" or "the mutator/validator rejected the write" (e.g. a kind-cap or maxStacks breach).
	-- Bailing out first, the same way addUnique does, keeps those two cases distinguishable so the
	-- reason below isn't a guess.
	if not PlayerDataService:getActiveSlot(userId) then
		local reason = `no profile loaded for userId {userId}`
		log:warn(`addItem("{itemType}") refused for userId {userId}:`, reason)
		return false, reason
	end

	local stackMax, maxStacks = stackLimitsOf(definition)
	local kind = definition.kind
	local reason: string? = nil

	local ok, validatorReason = inventorySlice.mutate(userId, function(inventory)
		local plan = InventoryPlacementUtils.planStackPlacement(
			inventory.items,
			itemType,
			count,
			stackMax,
			maxStacks,
			kind,
			inventoryHasRoom
		)
		if not plan.ok then
			reason = plan.reason
			return false
		end

		local updates = plan.updates
		assert(updates, "a feasible plan always carries updates")
		for index, newQuantity in updates do
			local stackEntry = inventory.items[index] :: PlayerDataTypes.StackEntry
			stackEntry.quantity = newQuantity
		end

		local newStacks = plan.newStacks
		assert(newStacks, "a feasible plan always carries newStacks")
		for _, quantity in newStacks do
			table.insert(inventory.items, { itemType = itemType, quantity = quantity })
		end
		return true
	end)

	if not ok and reason == nil then
		reason = validatorReason or "mutation rejected (see server logs)"
	end
	if not ok then
		log:warn(`addItem("{itemType}") refused for userId {userId}:`, reason)
	end
	return ok, reason
end

-- Adds `count` of a UNIQUE itemType via one atomic transaction: the account's `itemMint` counter and
-- the inventory's new entries commit together or not at all (see the item-definition-model spec's
-- "atomic minting" pattern). `mintedUids` is an upvalue the itemMint op fills and the inventory op
-- reads — both ops run synchronously and in array order inside transaction(), so this is safe.
--
-- Deliberately does NOT pre-check the kind cap: the data-layer validator (validateInventory) is the
-- real backstop, and letting it reject the write here is what makes the mint atomic — a kind-cap
-- breach rolls back BOTH ops, so `nextUid` never advances for entries that were never actually
-- added. (Contrast addStackable, which precomputes feasibility because there IS a meaningful
-- feasibility question — how the count splits across stacks; a unique mint has no such question,
-- only pass/fail.)
--
-- `attrs`, when given, is stamped onto EVERY minted copy (each gets its own copy of the table, so no two
-- entries alias). A caller that wants different attrs per copy (independent hatch rolls) mints one at a
-- time.
local function addUnique(
	userId: number,
	itemType: string,
	count: number,
	attrs: { [string]: PlayerDataTypes.AttrValue }?
): (boolean, string?)
	-- Checked BEFORE minting either op: inventorySlice.op (registerSlot's op) ASSERTS when no active
	-- slot is resolvable, so an unloaded profile would otherwise throw here instead of failing
	-- gracefully like addStackable/removeItem do. Bailing out first, the same "no profile loaded" way
	-- those methods do, keeps this path non-throwing and lets the generic mint-rejection message below
	-- mean what it says — a validator/kind-cap rejection, not a missing profile.
	if not PlayerDataService:getActiveSlot(userId) then
		local reason = `no profile loaded for userId {userId}`
		log:warn(`addItem("{itemType}") refused for userId {userId}:`, reason)
		return false, reason
	end

	local mintedUids: { string } = {}
	-- `transaction()` returns (boolean, TransactionResult); a rejection here is always the
	-- data-layer validator (kind cap or another invariant — neither op above ever returns false
	-- itself), so `result.rejectionReason` carries the real cause instead of a guess.
	local ok, result = PlayerDataService:transaction({
		itemMintSlice.op(userId, function(mint)
			for _ = 1, count do
				table.insert(mintedUids, `{userId}_{mint.nextUid}`)
				mint.nextUid += 1
			end
			return true
		end),
		inventorySlice.op(userId, function(inventory)
			for _, uid in mintedUids do
				table.insert(inventory.items, {
					itemType = itemType,
					uid = uid,
					attrs = if attrs ~= nil then table.clone(attrs) else nil,
				})
			end
			return true
		end),
	})

	if not ok then
		local reason = result.rejectionReason
			or `mint transaction for "{itemType}" was rejected (kind cap or an invariant violation)`
		log:warn(`addItem("{itemType}") refused for userId {userId}:`, reason)
		return false, reason
	end
	return true
end

-- Removes exactly the UniqueEntry identified by `uid`, or refuses if none matches.
local function removeByUid(userId: number, uid: string): (boolean, string?)
	-- Checked BEFORE mutating, same pattern as addUnique/addStackable: distinguishes "no profile
	-- loaded" from a mutator/validator rejection so the reason below isn't a guess.
	if not PlayerDataService:getActiveSlot(userId) then
		local reason = `no profile loaded for userId {userId}`
		log:warn(`removeItem(uid="{uid}") refused for userId {userId}:`, reason)
		return false, reason
	end

	local reason: string? = nil
	local ok, validatorReason = inventorySlice.mutate(userId, function(inventory)
		local index = InventoryUtils.findByUid(inventory, uid)
		if not index then
			reason = `no item with uid "{uid}"`
			return false
		end
		table.remove(inventory.items, index)
		return true
	end)
	if not ok and reason == nil then
		reason = validatorReason or "mutation rejected (see server logs)"
	end
	if not ok then
		log:warn(`removeItem(uid="{uid}") refused for userId {userId}:`, reason)
	end
	return ok, reason
end

-- Removes `quantity` of `itemType` across as many stacks (or unique instances) as needed. Refuses
-- up front (before any write) if the total held is short, so a partial removal never happens: the
-- availability check runs BEFORE the removal loop, over a fresh countOf snapshot.
local function removeByTypeAndQuantity(userId: number, itemType: string, quantity: number): (boolean, string?)
	-- Checked BEFORE mutating, same pattern as addUnique/addStackable/removeByUid: distinguishes
	-- "no profile loaded" from a mutator/validator rejection so the reason below isn't a guess.
	if not PlayerDataService:getActiveSlot(userId) then
		local reason = `no profile loaded for userId {userId}`
		log:warn(`removeItem("{itemType}", {quantity}) refused for userId {userId}:`, reason)
		return false, reason
	end

	local reason: string? = nil
	local ok, validatorReason = inventorySlice.mutate(userId, function(inventory)
		local available = InventoryUtils.countOf(inventory, itemType)
		if available < quantity then
			reason = `insufficient "{itemType}" (have {available}, need {quantity})`
			return false
		end

		local remaining = quantity
		-- Walk backwards so table.remove (which shifts later indices down) never disturbs an index
		-- not yet visited.
		for index = #inventory.items, 1, -1 do
			if remaining <= 0 then
				break
			end
			local entry = inventory.items[index]
			if entry.itemType ~= itemType then
				continue
			end
			if ItemRegistry.isStackable(entry.itemType) then
				local stackEntry = entry :: PlayerDataTypes.StackEntry
				if stackEntry.quantity <= remaining then
					remaining -= stackEntry.quantity
					table.remove(inventory.items, index)
				else
					stackEntry.quantity -= remaining
					remaining = 0
				end
			else
				remaining -= 1
				table.remove(inventory.items, index)
			end
		end
		return true
	end)
	if not ok and reason == nil then
		reason = validatorReason or "mutation rejected (see server logs)"
	end
	if not ok then
		log:warn(`removeItem("{itemType}", {quantity}) refused for userId {userId}:`, reason)
	end
	return ok, reason
end

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	The module below is one annotated table literal. Annotating the literal makes Luau push each
	signature from this interface DOWN into the matching method body, so the methods need NO inline
	type annotations. Types live in exactly one place, and there are zero casts outside the ones
	documented at their call sites.

	Reads/writes go through `inventorySlice` / `itemMintSlice` (PlayerDataSliceSystem) rather than
	PlayerDataService directly: the slice owns its path string and type, so there is no stringly-typed
	path to typo and every mutator argument is typed without an inline annotation.

	Writes reach the owning client through the reactive path only: a mutation updates the profile,
	`PlayerDataServiceServer:mutate`/`:transaction` mirrors the slice into `StateSyncServerStore`, and
	charm-sync ships the delta. There is no per-write broadcast packet.
]=]
export type InventoryServiceServer = {
	dependencies: { string },

	getInventory: (self: InventoryServiceServer, userId: number) -> PlayerDataTypes.Inventory?,
	addItem: (
		self: InventoryServiceServer,
		userId: number,
		itemType: string,
		count: number?,
		attrs: { [string]: PlayerDataTypes.AttrValue }?
	) -> (boolean, string?),
	removeItem: (
		self: InventoryServiceServer,
		userId: number,
		spec: { uid: string } | { itemType: string, quantity: number }
	) -> (boolean, string?),
	hasItem: (self: InventoryServiceServer, userId: number, itemType: string, quantity: number?) -> boolean,
	inventoryOp: (
		self: InventoryServiceServer,
		userId: number,
		mutator: (inventory: PlayerDataTypes.Inventory) -> boolean
	) -> PlayerDataService.TransactionOperation,
	-- Inventory's ENTRY-CAPACITY policy (per-kind KIND_CAPS), exposed as a InventoryPlacementUtils.RoomCheck
	-- so another container placing stackables INTO inventory (e.g. a stash withdraw) reuses it instead of
	-- duplicating the per-kind rule. Not a method — a plain function value.
	roomCheck: InventoryPlacementUtils.RoomCheck,
}

local InventoryServiceServer: InventoryServiceServer = {
	dependencies = { "PlayerDataServiceServer" },

	-- Inventory's per-kind cap policy, reusable by other containers placing into inventory (see the
	-- interface note). Points at the module-local `inventoryHasRoom` defined above.
	roomCheck = inventoryHasRoom,

	--[=[
		Gets the inventory wrapper for a user's ACTIVE character.
		@param userId number -- The user ID to get inventory for
		@return PlayerDataTypes.Inventory? -- The inventory, or nil if the profile is not loaded
	]=]
	getInventory = function(_self, userId)
		return inventorySlice.get(userId)
	end,

	--[=[
		Adds `count` (default 1) of a registered `itemType` to a player's ACTIVE inventory,
		ALL-OR-NOTHING: either every unit lands, or nothing is written.

		Stackable itemTypes merge into existing stacks (up to stackMax) and spill into new stacks
		(bounded by maxStacks and the kind cap) in a single mutate, with feasibility computed before
		any write. Unique itemTypes mint `count` fresh, collision-proof uids via one atomic
		transaction spanning the account-wide mint counter and the inventory (see addUnique).

		`attrs` is per-instance data stamped onto each minted copy of a UNIQUE item (a pet's level, a
		rolled mutation). It is refused for a stackable itemType: stacks are fungible, so they cannot
		carry per-instance data.

		@param userId number -- The user ID
		@param itemType string -- A registered item type key
		@param count number? -- How many to add (defaults to 1; must be a positive integer)
		@param attrs { [string]: AttrValue }? -- Per-instance data for unique items (see PlayerDataTypes)
		@return boolean, string? -- (ok, reason-on-failure)
	]=]
	addItem = function(_self, userId, itemType, count, attrs)
		Guard.userId(userId)
		assert(type(itemType) == "string", `itemType must be a string, got {type(itemType)}`)
		local wanted = if count == nil then 1 else count
		assert(
			type(wanted) == "number" and wanted > 0 and wanted == math.floor(wanted),
			`count must be a positive integer, got {tostring(count)}`
		)

		if not ItemRegistry.isValidItemType(itemType) then
			return false, `"{itemType}" is not a registered item type`
		end

		if ItemRegistry.isStackable(itemType) then
			if attrs ~= nil then
				return false, `"{itemType}" is stackable; stacks cannot carry per-instance attrs`
			end
			local definition = ItemRegistry.get(itemType)
			assert(definition, `itemType "{itemType}" passed isValidItemType but is missing from the registry`)
			return addStackable(userId, itemType, definition, wanted)
		end

		local attrsOk, attrsReason = InventoryUtils.validateAttrs(attrs)
		if not attrsOk then
			return false, attrsReason
		end
		return addUnique(userId, itemType, wanted, attrs)
	end,

	--[=[
		Removes an item from a player's ACTIVE inventory, either by exact `uid` (a UniqueEntry) or by
		`itemType` + `quantity` (decrementing/consuming across as many stacks or unique instances as
		needed). Refuses (returning false, unchanged) rather than partially applying when the request
		can't be fully met.
		@param userId number -- The user ID
		@param spec { uid: string } | { itemType: string, quantity: number } -- What to remove
		@return boolean, string? -- (ok, reason-on-failure)
	]=]
	removeItem = function(_self, userId, spec)
		Guard.userId(userId)
		assert(type(spec) == "table", `spec must be a table, got {type(spec)}`)

		-- The two branches of the spec union share no common field, so discriminate by casting to
		-- EACH union member in turn and checking which one actually has its field populated — the
		-- same legal same-union-member cast validateInventory uses (a cast to a type that IS already
		-- one arm of `spec`'s static union, not a fabricated unrelated shape).
		local asUid = spec :: { uid: string }
		if asUid.uid ~= nil then
			assert(type(asUid.uid) == "string" and asUid.uid ~= "", `uid must be a non-empty string`)
			return removeByUid(userId, asUid.uid)
		end

		local asTypeQuantity = spec :: { itemType: string, quantity: number }
		local itemType = asTypeQuantity.itemType
		local quantity = asTypeQuantity.quantity
		assert(type(itemType) == "string" and itemType ~= "", `itemType must be a non-empty string`)
		assert(
			type(quantity) == "number" and quantity > 0 and quantity == math.floor(quantity),
			`quantity must be a positive integer, got {tostring(quantity)}`
		)
		return removeByTypeAndQuantity(userId, itemType, quantity)
	end,

	--[=[
		True iff a player's ACTIVE inventory holds at least `quantity` (default 1) of `itemType`.
		@param userId number -- The user ID
		@param itemType string -- The item type key
		@param quantity number? -- Required amount (defaults to 1)
		@return boolean
	]=]
	hasItem = function(self, userId, itemType, quantity)
		Guard.userId(userId)
		assert(type(itemType) == "string", `itemType must be a string, got {type(itemType)}`)
		if quantity ~= nil then
			Guard.positiveAmount(quantity)
		end

		local inventory = self:getInventory(userId)
		if not inventory then
			return false
		end
		return InventoryUtils.hasItem(inventory, itemType, quantity)
	end,

	--[=[
		Mints a typed TransactionOperation over the inventory slice, for composing multi-slice /
		multi-player atomic writes via `PlayerDataService:transaction()` — e.g. a trade pairing this
		with `CurrencyService:currencyOp`. The mutator's `inventory` param is fully typed. Pure
		packaging: nothing runs (and no validation beyond userId) until transaction() executes.
		@param userId number -- The user ID the op targets
		@param mutator (inventory: Inventory) -> boolean -- Typed mutator; return false to abort the transaction
		@return PlayerDataService.TransactionOperation
	]=]
	inventoryOp = function(_self, userId, mutator)
		return inventorySlice.op(userId, mutator)
	end,
	-- No getState: inventory data lives in PlayerDataServiceServer profiles and the State tab already
	-- renders the synced "inventory" slice; there is nothing derived or diagnostic to add here. See
	-- ServiceController's getState field doc comment for the convention.
}

return InventoryServiceServer
