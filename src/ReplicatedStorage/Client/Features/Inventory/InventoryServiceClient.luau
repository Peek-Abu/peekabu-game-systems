--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemShared = ReplicatedStorage.Shared.Features.Item
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local InventoryUtils = require(ReplicatedStorage.Shared.Features.Inventory.Utils.InventoryUtils)
local ItemConstants = require(ItemShared.Data.ItemConstants)
local ItemRegistry = require(ItemShared.Data.ItemRegistry)
local ItemAffixConstants = require(ItemShared.Data.ItemAffixConstants)

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	A thin read-facade over `StateSyncClientStore.inventory`, the one client source of truth (populated by
	charm-sync). Reactive UI reads the atom directly via `useAtom`; imperative callers use this
	point-in-time accessor. There is no listener, cache, or signal here — those retired when the
	reactive store became the single client store.
]=]
export type InventoryServiceClient = {
	dependencies: { string },

	getInventory: (self: InventoryServiceClient) -> PlayerDataTypes.Inventory,
	getEntriesOfKind: (self: InventoryServiceClient, kind: string) -> { PlayerDataTypes.InventoryEntry },
	getAffixes: (self: InventoryServiceClient, entry: PlayerDataTypes.UniqueEntry) -> { [string]: number }?,
	displayName: (self: InventoryServiceClient, entry: PlayerDataTypes.UniqueEntry) -> string,
	getState: (self: InventoryServiceClient) -> { [string]: any },
}

local InventoryServiceClient: InventoryServiceClient = {
	dependencies = {},

	--[=[
		Gets the local player's inventory from the reactive store.
		@return PlayerDataTypes.Inventory -- The inventory wrapper (empty items until the first sync)
	]=]
	getInventory = function(_self)
		return StateSyncClientStore.inventory()
	end,

	--[=[
		All entries in the local player's inventory whose registered item kind matches `kind` — the
		UI-tab query. Delegates straight to InventoryUtils.entriesOfKind, the single source of truth
		for that filter.
		@param kind string
		@return { PlayerDataTypes.InventoryEntry } -- empty before the first sync
	]=]
	getEntriesOfKind = function(self, kind)
		return InventoryUtils.entriesOfKind(self:getInventory(), kind)
	end,

	--[=[
		The rolled affix map on a unique entry (nil when it has none) — a passthrough so UI reads affixes
		through the service facade rather than poking the entry field directly.
		@param entry PlayerDataTypes.UniqueEntry
		@return { [string]: number }? -- affixId -> rolled value, or nil
	]=]
	getAffixes = function(_self, entry)
		return entry.affixes
	end,

	--[=[
		The display name for a unique entry: the item's definition name, prefixed with its affix's
		display name when it has one ("Titan's Rusted Saw Blade"). Derived at render time from
		ItemAffixConstants — the prefix is never stored on the entry (see the affix-rolling spec, Decision 9).
		@param entry PlayerDataTypes.UniqueEntry
		@return string
	]=]
	displayName = function(_self, entry)
		local definition = ItemRegistry.get(entry.itemType)
		local baseName = if definition then definition.name else entry.itemType
		local prefix = ItemAffixConstants.displayPrefix(entry.affixes)
		if prefix then
			return `{prefix} {baseName}`
		end
		return baseName
	end,

	--[=[
		Returns DERIVED debugger state: entry count against KIND_CAPS per registered kind, the cap
		meter the raw "inventory" slice view (already shown by the State tab) doesn't compute.
		@return { [string]: any } -- Service state
	]=]
	getState = function(self)
		local inventory = self:getInventory()
		local entriesPerKind: { [string]: string } = {}
		for _, kind in ItemConstants.KINDS do
			entriesPerKind[kind] =
				`{InventoryUtils.countEntriesOfKind(inventory, kind)}/{ItemConstants.KIND_CAPS[kind]}`
		end
		return {
			entriesPerKind = entriesPerKind,
		}
	end,
}

return InventoryServiceClient
