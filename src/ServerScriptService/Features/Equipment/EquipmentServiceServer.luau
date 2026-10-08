--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EquipmentShared = ReplicatedStorage.Shared.Features.Equipment
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local InventoryUtils = require(ReplicatedStorage.Shared.Features.Inventory.Utils.InventoryUtils)
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)
local ItemConstants = require(ReplicatedStorage.Shared.Features.Item.Data.ItemConstants)
local EquipmentConstants = require(EquipmentShared.Data.EquipmentConstants)
local StatFormulas = require(ReplicatedStorage.Shared.Features.Stat.Utils.StatFormulas)
local EquipmentBonusFormulas = require(EquipmentShared.Utils.EquipmentBonusFormulas)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local EquipmentEvents = require(EquipmentShared.Net.EquipmentEvents)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local StatServiceServer = require(ServerScriptService.Features.Stat.StatServiceServer)

--[=[
	The equipment invariant, enforced by the DATA LAYER on every write (see PlayerDataSliceSystem's `validate`).
	`equip`/`unequip` already respect it, but registering it here makes it hold for ANY path into the
	slice — including a raw `PlayerDataService:transaction()` op that never goes through
	equip/unequip. Runs after a mutator, inside the no-yield region, so it must stay pure/synchronous.

	Rules (see the equipment-gear-stats design spec):
	1. every occupied slot key is a valid EquipmentConstants.SLOTS id;
	2. every occupied slot's entry's registered kind (ItemRegistry.kindOf) matches that slot's
	   acceptsKind — defense in depth beyond the service-level check in `equip`;
	3. no uid appears in more than one slot.
]=]
local function validateEquipment(equipment: PlayerDataTypes.Equipment): (boolean, string?)
	if type(equipment) ~= "table" then
		return false, `equipment must be a table, got {type(equipment)}`
	end
	if type(equipment.slots) ~= "table" then
		return false, `equipment.slots must be a table, got {type(equipment.slots)}`
	end

	local seenUids: { [string]: boolean } = {}
	for slotId, entry in equipment.slots do
		if not EquipmentConstants.isValidSlot(slotId) then
			return false, `"{slotId}" is not a registered equipment slot`
		end
		if type(entry) ~= "table" or type(entry.itemType) ~= "string" then
			return false, `equipment.slots["{slotId}"] must be a UniqueEntry table`
		end

		local slotConfig = EquipmentConstants.SLOTS[slotId]
		assert(slotConfig, "isValidSlot proved this slot id is registered")
		local kind = ItemRegistry.kindOf(entry.itemType)
		if kind ~= slotConfig.acceptsKind then
			return false,
				`equipment.slots["{slotId}"] holds a "{tostring(kind)}" item, but that slot only accepts "{slotConfig.acceptsKind}"`
		end

		local uid = entry.uid
		if type(uid) ~= "string" or uid == "" then
			return false, `equipment.slots["{slotId}"] has an invalid uid {tostring(uid)}`
		end
		if seenUids[uid] then
			return false, `duplicate uid "{uid}" across equipment slots`
		end
		seenUids[uid] = true

		-- Per-instance modifier maps ride on the equipped entry too — same rule as the inventory
		-- validator (values must be finite; retired keys tolerated). Defense in depth: an equipped entry
		-- re-enters through this validator on every equip/unequip.
		local okAffixes, affixReason = InventoryUtils.validateModifierMap(entry.affixes)
		if not okAffixes then
			return false, `equipment.slots["{slotId}"]: {affixReason}`
		end
		local okStatRolls, statRollReason = InventoryUtils.validateModifierMap(entry.statRolls)
		if not okStatRolls then
			return false, `equipment.slots["{slotId}"]: {statRollReason}`
		end
	end

	return true
end

-- Registers "equipment" as a SLOT-SCOPED slice: each character has its own equipped gear. See
-- InventoryServiceServer's "inventory" registration for the same slot-scoped rationale.
local equipmentSlice = PlayerDataSliceSystem.registerSlot("equipment", { slots = {} }, function(slot)
	return slot.equipment
end, validateEquipment)

--[=[
	Public interface of the service — the SINGLE place method/field types are declared. Mirrors
	InventoryServiceServer/StatServiceServer's shape: an annotated table literal, methods as fields,
	zero inline annotations in the bodies.

	Reads/writes go through `equipmentSlice` (PlayerDataSliceSystem) rather than PlayerDataService directly, and
	`equip`/`unequip` compose with InventoryServiceServer's PUBLIC `inventoryOp`/`getInventory` — never
	its private `inventorySlice` local, which isn't exported. Writes reach the owning client through
	the reactive path only: a mutation updates the profile, PlayerDataServiceServer mirrors the slice
	into StateSyncServerStore, and charm-sync ships the delta.
]=]
export type EquipmentServiceServer = {
	dependencies: { string },

	getEquipment: (self: EquipmentServiceServer, userId: number) -> PlayerDataTypes.Equipment?,
	equip: (self: EquipmentServiceServer, userId: number, uid: string) -> (boolean, string?),
	unequip: (self: EquipmentServiceServer, userId: number, slotId: string) -> (boolean, string?),
	equipmentOp: (
		self: EquipmentServiceServer,
		userId: number,
		fn: (equipment: PlayerDataTypes.Equipment) -> boolean
	) -> PlayerDataService.TransactionOperation,
	getAggregatedBonuses: (self: EquipmentServiceServer, userId: number) -> { [string]: number },
	getState: (self: EquipmentServiceServer) -> { [string]: any },
	init: (self: EquipmentServiceServer) -> (),
	stop: (self: EquipmentServiceServer) -> (),
}

local log = Logger.new("EquipmentServiceServer")
local janitor = Janitor.new()

-- Rate limits sized for HANDS, not for scripts: equipping is a deliberate act, and a player swapping
-- gear as fast as they can click is still well under this. Anything above it is not a person.
local EQUIP_RATE_LIMIT = { maxRequests = 20, windowSeconds = 5 }

-- Forward-declared so the service table below can close over them, and ASSIGNED after it: both handlers
-- call the service's own equip/unequip, which does not exist yet at this point in the file.
local onEquipItem: (uid: string, player: Player) -> any
local onUnequipItem: (slotId: string, player: Player) -> any

local EquipmentServiceServer: EquipmentServiceServer = {
	dependencies = { "PlayerDataServiceServer", "InventoryServiceServer", "StatServiceServer" },

	--[=[
		Gets the equipped-gear wrapper for a user's ACTIVE character.
		@param userId number -- The user ID to get equipment for
		@return PlayerDataTypes.Equipment? -- The equipment, or nil if the profile is not loaded
	]=]
	getEquipment = function(_self, userId)
		return equipmentSlice.get(userId)
	end,

	--[=[
		Equips the UniqueEntry identified by `uid` out of the player's ACTIVE inventory into its item's
		registered `equipSlot`, ALL-OR-NOTHING: either the swap fully lands, or nothing moves.

		A read-only pre-flight (before building any transaction) resolves the item and refuses early for
		developer-facing/player-facing reasons that don't need the lock: unknown uid, non-equippable
		kind, an unmet `requiredLevel`. The actual move is a 3-op transaction (inventory-remove,
		equipment-place-and-capture-previous-occupant, inventory-reinsert-previous-occupant) so a
		SWAP into an occupied slot returns the old item to the bag atomically with the new item leaving
		it — see the design spec's Decision 3.
		@param userId number -- The user ID
		@param uid string -- The inventory UniqueEntry's uid to equip
		@return boolean, string? -- (ok, reason-on-failure)
	]=]
	equip = function(_self, userId, uid)
		Guard.userId(userId)

		local inventory = InventoryServiceServer:getInventory(userId)
		if not inventory then
			return false, `no profile loaded for userId {userId}`
		end
		local _, foundEntry = InventoryUtils.findByUid(inventory, uid)
		if not foundEntry then
			return false, `no item with uid "{uid}"`
		end
		local definition = ItemRegistry.get(foundEntry.itemType)
		assert(definition, `"{foundEntry.itemType}" is in an inventory but has no ItemDefinition`)
		if definition.kind ~= "weapon" and definition.kind ~= "armour" then
			return false, `"{foundEntry.itemType}" is not equippable`
		end
		local slotConfig = EquipmentConstants.SLOTS[definition.equipSlot]
		assert(
			slotConfig and slotConfig.acceptsKind == definition.kind,
			`"{foundEntry.itemType}"'s equipSlot "{definition.equipSlot}" is misconfigured`
		)
		if definition.requiredLevel then
			local stats = StatServiceServer:getStats(userId)
			local level = if stats then StatFormulas.levelOf(stats.totalXp) else 0
			if level < definition.requiredLevel then
				return false, `requires level {definition.requiredLevel}, you are level {level}`
			end
		end

		-- `movedEntry` is re-derived FRESH inside the first op (from the live inventory at commit
		-- time), not reused from the pre-flight read above — exactly like removeByUid re-derives its
		-- target rather than trusting a snapshot taken before the lock.
		local previousOccupant: PlayerDataTypes.UniqueEntry? = nil
		local movedEntry: PlayerDataTypes.UniqueEntry? = nil
		local reason: string? = nil
		-- `transaction()` returns (boolean, TransactionResult) — a player-facing reason can come
		-- from either an upvalue an aborting op sets itself (checked first below — it is the more
		-- specific, business-logic cause), or, when no op aborted itself but the data-layer validator
		-- rejected the commit anyway (e.g. validateEquipment), from `result.rejectionReason`.
		local ok, result = PlayerDataService:transaction({
			InventoryServiceServer:inventoryOp(userId, function(inv)
				local index, entry = InventoryUtils.findByUid(inv, uid)
				if not index then
					reason = `no item with uid "{uid}"`
					return false
				end
				movedEntry = entry
				table.remove(inv.items, index)
				return true
			end),
			equipmentSlice.op(userId, function(equipment)
				previousOccupant = equipment.slots[definition.equipSlot]
				assert(movedEntry, "the inventory-remove op runs before this op and always sets movedEntry")
				equipment.slots[definition.equipSlot] = movedEntry
				return true
			end),
			InventoryServiceServer:inventoryOp(userId, function(inv)
				if previousOccupant then
					table.insert(inv.items, previousOccupant)
				end
				return true
			end),
		})
		if not ok and reason == nil then
			reason = result.rejectionReason or "mutation rejected (see server logs)"
		end
		return ok, reason
	end,

	--[=[
		Unequips whatever occupies `slotId`, returning it to the player's ACTIVE inventory,
		ALL-OR-NOTHING: either the item lands back in the bag, or nothing moves.

		A single 2-op transaction (equipment-clear-and-capture, inventory-reinsert) composes with
		InventoryServiceServer's registered validator, so a kind-cap-full bag is the real BACKSTOP that
		still refuses the unequip even if the pre-flight below is ever bypassed (per the design spec's
		Decision 3) — and because it is one transaction, that refusal rolls the equipment clear back
		too, leaving the slot occupied.

		A read-only pre-flight (before building the transaction) additionally checks the kind cap
		itself and returns a SPECIFIC reason when it would be exceeded: `transaction()`'s second return
		is a persistence summary (TransactionResult), not a failure reason (see
		PlayerDataServiceServer.TransactionResult — it carries only committed/persisted/failedUserIds),
		so without this pre-flight a validator-triggered refusal here would fall through to the generic
		"mutation rejected" message. The validator remains the authoritative guarantee; this is best-effort
		early detection of the one predictable rejection reason, same pre-flight-vs-guarantee split
		`equip` already uses for uid/kind/requiredLevel.
		@param userId number -- The user ID
		@param slotId string -- The EquipmentConstants slot id to clear
		@return boolean, string? -- (ok, reason-on-failure)
	]=]
	unequip = function(_self, userId, slotId)
		Guard.userId(userId)
		if not EquipmentConstants.isValidSlot(slotId) then
			return false, `"{slotId}" is not a valid equipment slot`
		end
		if not PlayerDataService:getActiveSlot(userId) then
			return false, `no profile loaded for userId {userId}`
		end

		local equipment = equipmentSlice.get(userId)
		assert(equipment, "getActiveSlot proved a profile is loaded")
		local currentOccupant = equipment.slots[slotId]
		if not currentOccupant then
			return false, `slot "{slotId}" is empty`
		end

		local kind = ItemRegistry.kindOf(currentOccupant.itemType)
		if kind then
			local inventory = InventoryServiceServer:getInventory(userId)
			local cap = ItemConstants.KIND_CAPS[kind]
			if inventory and cap and InventoryUtils.countEntriesOfKind(inventory, kind) >= cap then
				return false, `cannot unequip: {kind} inventory is at its cap ({cap})`
			end
		end

		-- Re-derived FRESH inside the op at commit time, not reused from the read above.
		local freedEntry: PlayerDataTypes.UniqueEntry? = nil
		local reason: string? = nil
		-- Same pattern as `equip`: an aborting op's own upvalue reason wins (more specific), falling
		-- back to `result.rejectionReason` when the data-layer validator rejected the commit instead
		-- (the kind-cap pre-flight above catches the common case early, but this backs the rest).
		local ok, result = PlayerDataService:transaction({
			equipmentSlice.op(userId, function(current)
				local occupant = current.slots[slotId]
				if not occupant then
					reason = `slot "{slotId}" is empty`
					return false
				end
				freedEntry = occupant
				current.slots[slotId] = nil
				return true
			end),
			InventoryServiceServer:inventoryOp(userId, function(inv)
				assert(freedEntry, "the equipment-clear op runs before this op and always sets freedEntry")
				table.insert(inv.items, freedEntry)
				return true
			end),
		})
		if not ok and reason == nil then
			reason = result.rejectionReason or "mutation rejected (see server logs)"
		end
		return ok, reason
	end,

	--[=[
		Mints a typed TransactionOperation over the equipment slice, for composing multi-slice atomic
		writes via `PlayerDataService:transaction()` (the same primitive InventoryServiceServer's
		`inventoryOp` provides). Pure packaging: nothing runs until transaction() executes.
		@param userId number -- The user ID the op targets
		@param fn (equipment: Equipment) -> boolean -- Typed mutator; return false to abort the transaction
		@return PlayerDataService.TransactionOperation
	]=]
	equipmentOp = function(_self, userId, fn)
		return equipmentSlice.op(userId, fn)
	end,

	--[=[
		Sums every equipped entry's `statBonuses`, keyed by StatConstants stat id — the modifier layer
		StatFormulas.derive's `sources` parameter expects. {} if nothing is equipped or no profile is
		mirrored (never throws). Thin wrapper over `EquipmentBonusFormulas.aggregate` (the pure implementation,
		shared with `StatServiceServer` — see that module's header for why the aggregation itself had
		to move out of this service).

		Reads the COMMITTED StateSyncServerStore mirror of the "equipment" slice — the SAME source
		`StatServiceServer.getDerived` aggregates over — rather than `self:getEquipment(userId)` (the
		live profile read). This has no production callers today, but it exists as the public surface a
		future caller reaches for expecting parity with what drives `MaxHealth`; reading the profile and
		the mirror through two different paths would be an unenforced invariant that happens to hold
		only because `PlayerDataService` mirrors synchronously after every committed write. Pointing both
		readers at the mirror makes them byte-identical by construction instead. The snapshot is
		`unknown` at this generic StateSyncServerStore boundary by design (see `StateSyncServerStore`'s header); the cast
		below is the same one-site, documented narrowing `StatServiceServer.getDerived` performs at the
		same boundary, not a fresh cast invented to dodge strictness.
		@param userId number -- The user ID
		@return { [string]: number } -- Summed bonuses, keyed by stat id
	]=]
	getAggregatedBonuses = function(_self, userId)
		local equipmentSnapshot = StateSyncServerStore.getterFor("equipment", userId)() :: PlayerDataTypes.Equipment? -- narrowing the generic StateSyncServerStore boundary, see above
		return EquipmentBonusFormulas.aggregate(equipmentSnapshot)
	end,

	--[=[
		Returns DIAGNOSTIC/DERIVED debugger state: every registered slot id and the item kind it
		accepts — the static slot registry, not a per-player value the State tab's raw "equipment"
		slice view already shows.
		@return { [string]: any } -- Service state
	]=]
	--[=[
		Wires the equip/unequip packet listeners. This is the framework's first gameplay write from a
		client, so the guard rails matter: RequestHandler applies the rate limit and isolates a throwing
		handler, and the rules themselves stay in equip/unequip so this path and the Cmdr commands cannot
		disagree about what is legal.
		@param self EquipmentServiceServer -- The service instance
	]=]
	init = function(_self)
		-- ByteNet hands the server (data, player). A nil player means a malformed frame, not a request.
		janitor:Add(
			EquipmentEvents.packets.EquipItem.listen(function(uid: string, player: Player?)
				if player then
					onEquipItem(uid, player)
				end
			end),
			true
		)
		janitor:Add(
			EquipmentEvents.packets.UnequipItem.listen(function(slotId: string, player: Player?)
				if player then
					onUnequipItem(slotId, player)
				end
			end),
			true
		)
	end,

	--[=[
		Drops the packet listeners.
		@param self EquipmentServiceServer -- The service instance
	]=]
	stop = function(_self)
		janitor:Cleanup()
	end,

	getState = function(_self)
		local slots: { [string]: string } = {}
		for slotId, slotConfig in EquipmentConstants.SLOTS do
			slots[slotId] = slotConfig.acceptsKind
		end
		return {
			slots = slots,
		}
	end,
}

-- Both handlers are thin: every ownership, slot and stackability rule already lives in `equip`/`unequip`,
-- which the Cmdr commands call too. The packet path adds no rules of its own — if it did, the two entry
-- points could disagree about what is legal.
onEquipItem = RequestHandler.wrap({
	name = "EquipmentEquipItem",
	rateLimit = EQUIP_RATE_LIMIT,
	rateLimitKey = "Equipment", -- equip and unequip are one gesture budget, not two (see BankReceiver)
	handler = function(uid: string, player: Player)
		local ok, reason = EquipmentServiceServer:equip(player.UserId, uid)
		if not ok then
			-- Expected and not an error: a stale click on an item that just moved lands here.
			log:debug("Equip refused for", player.Name, "-", reason)
		end
	end,
})

onUnequipItem = RequestHandler.wrap({
	name = "EquipmentUnequipItem",
	rateLimit = EQUIP_RATE_LIMIT,
	rateLimitKey = "Equipment",
	handler = function(slotId: string, player: Player)
		local ok, reason = EquipmentServiceServer:unequip(player.UserId, slotId)
		if not ok then
			log:debug("Unequip refused for", player.Name, "-", reason)
		end
	end,
})

return EquipmentServiceServer
