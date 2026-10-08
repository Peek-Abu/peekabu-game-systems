--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataType = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local ItemConstants = require(ReplicatedStorage.Shared.Features.Item.Data.ItemConstants)
local EquipmentConstants = require(ReplicatedStorage.Shared.Features.Equipment.Data.EquipmentConstants)
local StatConstants = require(ReplicatedStorage.Shared.Features.Stat.Data.StatConstants)

--[=[
	Registry of item definitions (itemType -> display + kind metadata).

	The backing map is PRIVATE and accessed only through register/get/isValidItemType. This is
	deliberate: a module typed as a public `{ [string]: ItemDefinition }` map cannot also hold
	helper functions (the indexer would claim every key, including `isValidItemType`, is an
	ItemDefinition). Keeping the map private lets the module be a clean function table.

	`register` is a developer-error contract, not a runtime-refusal one: it VALIDATES against
	ItemConstants and asserts loudly at boot (ItemContentRegistry.init) rather than failing quietly. That
	includes rejecting a SECOND registration of the same item type outright — the old registry
	silently overwrote on re-register, which is exactly how the old game's dual-registry drift
	started (two call sites disagreeing about what "iron-sword" meant, and nobody finding out until
	a player saw the wrong item).

	@class ItemRegistry
]=]

local definitions: { [string]: PlayerDataType.ItemDefinition } = {}

local ItemRegistry = {}

--[=[
	Registers a NEW item definition. Called by ItemContentRegistry on startup.

	Developer-error asserts (loud throws, meant to be caught in dev/CI, never at live runtime):
	- `itemType` must not already be registered.
	- `definition.kind` must be a known ItemConstants kind.
	- `definition.rarity` must be a known ItemConstants rarity.
	- A `consumable` must carry an integer `stackMax >= 1`.
	- A declared `maxStacks` (consumable or misc) must be an integer `>= 1`.
	- A declared misc `stackMax` must be an integer `>= 1`.
	- A `weapon`/`armour`'s `equipSlot` must be a registered EquipmentConstants slot whose
	  `acceptsKind` matches the item's own kind.
	- A `weapon`/`armour`'s declared `requiredLevel` must be a positive integer.
	- A `weapon`/`armour`'s declared `statBonuses` must key only known StatConstants stat ids, with
	  every value a real number (negative bonuses are legal — future cursed gear — so only
	  numeric-ness is checked, not sign).

	@param itemType string -- The item type key (e.g. "rusted-saw")
	@param definition PlayerDataType.ItemDefinition -- The item's kind + display metadata
]=]
function ItemRegistry.register(itemType: string, definition: PlayerDataType.ItemDefinition)
	assert(definitions[itemType] == nil, `item type "{itemType}" is already registered`)
	assert(
		ItemConstants.isValidKind(definition.kind),
		`unknown item kind "{definition.kind}" for item type "{itemType}"`
	)
	assert(
		ItemConstants.isValidRarity(definition.rarity),
		`unknown rarity "{definition.rarity}" for item type "{itemType}"`
	)

	local function assertPositiveInteger(value: number, fieldName: string)
		assert(type(value) == "number", `{fieldName} must be a number for item type "{itemType}"`)
		assert(value >= 1, `{fieldName} must be >= 1 for item type "{itemType}"`)
		assert(value % 1 == 0, `{fieldName} must be an integer for item type "{itemType}"`)
	end

	if definition.kind == "consumable" then
		assertPositiveInteger(definition.stackMax, "stackMax")
		if definition.maxStacks ~= nil then
			assertPositiveInteger(definition.maxStacks, "maxStacks")
		end
	elseif definition.kind == "misc" then
		if definition.stackMax ~= nil then
			assertPositiveInteger(definition.stackMax, "stackMax")
		end
		if definition.maxStacks ~= nil then
			assertPositiveInteger(definition.maxStacks, "maxStacks")
		end
	elseif definition.kind == "weapon" or definition.kind == "armour" then
		assert(
			EquipmentConstants.isValidSlot(definition.equipSlot),
			`unknown equipSlot "{definition.equipSlot}" for item type "{itemType}"`
		)
		local slotConfig = EquipmentConstants.SLOTS[definition.equipSlot]
		assert(slotConfig, "isValidSlot proved this slot id is registered")
		assert(
			slotConfig.acceptsKind == definition.kind,
			`equipSlot "{definition.equipSlot}" accepts "{slotConfig.acceptsKind}", but item type "{itemType}" is "{definition.kind}"`
		)
		if definition.requiredLevel ~= nil then
			assertPositiveInteger(definition.requiredLevel, "requiredLevel")
		end
		if definition.statBonuses ~= nil then
			-- Collapse the WeaponDefinition|ArmourDefinition union's two structurally-identical
			-- `{ [string]: number }` arms into one type: Luau's generic-for cannot iterate a union of
			-- table types directly (no single call signature), even when both arms are identical.
			local statBonuses: { [string]: number } = definition.statBonuses
			for statId, bonus in statBonuses do
				assert(
					StatConstants.isValidStatId(statId),
					`unknown stat id "{statId}" in statBonuses for item type "{itemType}"`
				)
				assert(type(bonus) == "number", `statBonuses["{statId}"] must be a number for item type "{itemType}"`)
			end
		end
	end

	definitions[itemType] = definition
end

--[=[
	Gets an item definition by type, or nil if the type is unknown.
	@param itemType string -- The item type key
	@return PlayerDataType.ItemDefinition?
]=]
function ItemRegistry.get(itemType: string): PlayerDataType.ItemDefinition?
	return definitions[itemType]
end

--[=[
	Checks if the provided item type has a registered definition.
	@param itemType string -- The item type to validate
	@return boolean -- True if a definition exists, false otherwise
]=]
function ItemRegistry.isValidItemType(itemType: string): boolean
	return definitions[itemType] ~= nil
end

--[=[
	Returns every registered item type key. Used to build the Cmdr `itemType` enum so admin
	commands autocomplete and validate item names. Snapshot of whatever is registered when called,
	so register all items (ItemContentRegistry.init) before building the enum.
	@return { string } -- All registered item type keys
]=]
function ItemRegistry.getValidItemTypes(): { string }
	local types: { string } = {}
	for itemType in definitions do
		table.insert(types, itemType)
	end
	return types
end

--[=[
	The registered kind of an item type, or nil if the type is unknown.
	@param itemType string -- The item type key
	@return string? -- "weapon" | "armour" | "consumable" | "misc" | nil
]=]
function ItemRegistry.kindOf(itemType: string): string?
	local definition = definitions[itemType]
	if not definition then
		return nil
	end
	return definition.kind
end

--[=[
	True iff the item type's definition carries a `stackMax` — consumables always do (required at
	registration); misc items only when declared. Weapons and armour are never stackable. False for
	an unregistered item type.
	@param itemType string -- The item type key
	@return boolean
]=]
function ItemRegistry.isStackable(itemType: string): boolean
	local definition = definitions[itemType]
	if not definition then
		return false
	end
	if definition.kind == "consumable" then
		return true
	end
	if definition.kind == "misc" then
		return definition.stackMax ~= nil
	end
	return false
end

return ItemRegistry
