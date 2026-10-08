--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local SlotService = require(ServerScriptService.Features.Slot.SlotServiceServer)

return function(_context, target: Player, slot: number): string
	local unlocked = SlotService:unlockSlot(target.UserId, slot)
	if not unlocked then
		return `{target.Name} already owns slot {slot}`
	end
	return `Unlocked slot {slot} for {target.Name}`
end
