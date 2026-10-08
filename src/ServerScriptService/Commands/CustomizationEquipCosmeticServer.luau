--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)

-- "accessory" is slot-indexed (a character wears several at once); every other category is a single
-- selection, so the slot argument is meaningless there and deliberately ignored.
return function(_context, target: Player, category: string, id: string, slot: number)
	local success, reason
	if category == "accessory" then
		success, reason = CustomizationService:equipAccessory(target.UserId, slot, id)
	else
		success, reason = CustomizationService:equipCosmetic(target.UserId, category, id)
	end
	if success then
		return `Equipped {category} "{id}" for {target.Name}.`
	end
	return `Failed to equip "{id}" for {target.Name}: {reason or "unknown reason"}.`
end
