--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local InventoryService = require(ServerScriptService.Services.InventoryService.InventoryServiceServer)

return function(context, target: Player, itemType: string, quantity: number)
	local success = InventoryService:removeItem(target.UserId, {
		itemType = itemType,
	}, quantity)
	
	if success then
		return `Successfully removed {quantity}x {itemType} from {target.Name}.`
	else
		return `Failed to remove item from {target.Name}. Ensure they have enough.`
	end
end
