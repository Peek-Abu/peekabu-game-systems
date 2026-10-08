--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local EquipmentService = require(ServerScriptService.Features.Equipment.EquipmentServiceServer)

return function(_context, target: Player, slotId: string)
	local success, reason = EquipmentService:unequip(target.UserId, slotId)
	if success then
		return `Successfully unequipped slot "{slotId}" for {target.Name}.`
	else
		return `Failed to unequip item for {target.Name}: {reason or "unknown reason"}.`
	end
end
