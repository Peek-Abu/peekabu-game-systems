--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataType = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

--[=[
	Registry of item definitions (itemType -> display metadata).

	The backing map is PRIVATE and accessed only through register/get/isValidItemType. This is
	deliberate: a module typed as a public `{ [string]: ItemDefinition }` map cannot also hold
	helper functions (the indexer would claim every key, including `isValidItemType`, is an
	ItemDefinition). Keeping the map private lets the module be a clean function table.

	@class ItemDefinitions
]=]

local definitions: { [string]: PlayerDataType.ItemDefinition } = {}

local ItemDefinitions = {}

--[=[
	Registers (or overwrites) an item definition. Called by GameItems on startup.
	@param itemType string -- The item type key (e.g. "iron-sword")
	@param definition PlayerDataType.ItemDefinition -- The display metadata
]=]
function ItemDefinitions.register(itemType: string, definition: PlayerDataType.ItemDefinition)
	definitions[itemType] = definition
end

--[=[
	Gets an item definition by type, or nil if the type is unknown.
	@param itemType string -- The item type key
	@return PlayerDataType.ItemDefinition?
]=]
function ItemDefinitions.get(itemType: string): PlayerDataType.ItemDefinition?
	return definitions[itemType]
end

--[=[
	Checks if the provided item type has a registered definition.
	@param itemType string -- The item type to validate
	@return boolean -- True if a definition exists, false otherwise
]=]
function ItemDefinitions.isValidItemType(itemType: string): boolean
	return definitions[itemType] ~= nil
end

return ItemDefinitions
