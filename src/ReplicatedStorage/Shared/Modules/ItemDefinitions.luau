--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataType = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

--[=[
	Item definitions for all items in the game.
	Maps item type IDs to their display properties and metadata.
	@type ItemDefinitions {[string]: PlayerDataType.ItemDefinition}
]=]
local ItemDefinitions: { [string]: PlayerDataType.ItemDefinition } = {}
--[=[
	Checks if the provided item type is valid.
	@param itemType string -- The item type to validate
	@return boolean -- True if valid, false otherwise
]=]
function ItemDefinitions.isValidItemType(itemType: string): boolean
	return ItemDefinitions[itemType] ~= nil
end

return ItemDefinitions
