--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local InventoryService = require(ServerScriptService.Services.InventoryService.InventoryServiceServer)

return function(context, target: Player, itemType: string, quantity: number)
	local success = InventoryService:addItem(target.UserId, {
		itemType = itemType,
		quantity = quantity,
	})
	
	if success then
		return `Successfully gave {quantity}x {itemType} to {target.Name}.`
	else
		return `Failed to give item to {target.Name}. Check server logs.`
	end
end
