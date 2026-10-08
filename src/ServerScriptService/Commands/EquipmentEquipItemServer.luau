--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local EquipmentService = require(ServerScriptService.Features.Equipment.EquipmentServiceServer)

return function(_context, target: Player, uid: string)
	local success, reason = EquipmentService:equip(target.UserId, uid)
	if success then
		return `Successfully equipped uid {uid} for {target.Name}.`
	else
		return `Failed to equip item for {target.Name}: {reason or "unknown reason"}.`
	end
end
