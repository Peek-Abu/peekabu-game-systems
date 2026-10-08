--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local SlotService = require(ServerScriptService.Features.Slot.SlotServiceServer)

return function(_context, target: Player, slot: number): string
	local ok, reason = SlotService:switchSlot(target, slot)
	if not ok then
		return `Could not switch {target.Name} to slot {slot}: {reason or "unknown reason"}`
	end
	return `Switched {target.Name} to slot {slot}`
end
