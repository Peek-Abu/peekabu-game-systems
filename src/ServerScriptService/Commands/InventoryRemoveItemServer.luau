--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local InventoryService = require(ServerScriptService.Features.Inventory.InventoryServiceServer)

return function(_context, target: Player, itemType: string, quantity: number)
	local success, reason = InventoryService:removeItem(target.UserId, {
		itemType = itemType,
		quantity = quantity,
	})

	if success then
		return `Successfully removed {quantity}x {itemType} from {target.Name}.`
	else
		return `Failed to remove item from {target.Name}: {reason or "unknown reason"}.`
	end
end
