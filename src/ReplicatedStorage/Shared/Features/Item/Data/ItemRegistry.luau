--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataType = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local ItemConstants = require(ReplicatedStorage.Shared.Features.Item.Data.ItemConstants)

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
	- A declared `stackMax` must be an integer `>= 1` (its presence is what makes the item stackable).
	- A declared `maxStacks` must be an integer `>= 1`, and only makes sense on a stackable item.

	Game-specific fields (an equip slot, a level requirement, a pet's base stats) are added to
	`ItemDefinition` as optional fields and validated by the game's own registration step.

	@param itemType string -- The item type key (e.g. "wrench")
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

	if definition.stackMax ~= nil then
		assertPositiveInteger(definition.stackMax, "stackMax")
	end
	if definition.maxStacks ~= nil then
		assert(
			definition.stackMax ~= nil,
			`maxStacks needs stackMax (a unique item has no stacks) for item type "{itemType}"`
		)
		assertPositiveInteger(definition.maxStacks, "maxStacks")
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
	@return string? -- a registered ItemConstants kind, or nil
]=]
function ItemRegistry.kindOf(itemType: string): string?
	local definition = definitions[itemType]
	if not definition then
		return nil
	end
	return definition.kind
end

--[=[
	True iff the item type's definition declares a `stackMax` (stackability is declared, not inferred
	from kind). False for an unregistered item type.
	@param itemType string -- The item type key
	@return boolean
]=]
function ItemRegistry.isStackable(itemType: string): boolean
	local definition = definitions[itemType]
	return definition ~= nil and definition.stackMax ~= nil
end

return ItemRegistry
