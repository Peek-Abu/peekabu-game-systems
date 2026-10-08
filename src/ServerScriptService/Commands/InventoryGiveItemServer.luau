--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local InventoryService = require(ServerScriptService.Features.Inventory.InventoryServiceServer)

return function(_context, target: Player, itemType: string, quantity: number)
	local success, reason = InventoryService:addItem(target.UserId, itemType, quantity)

	if success then
		return `Successfully gave {quantity}x {itemType} to {target.Name}.`
	else
		return `Failed to give item to {target.Name}: {reason or "unknown reason"}.`
	end
end
