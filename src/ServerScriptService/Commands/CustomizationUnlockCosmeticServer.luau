--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)

return function(_context, target: Player, category: string, id: string)
	local success, reason = CustomizationService:unlockCosmetic(target.UserId, category, id)
	if success then
		return `Unlocked {category} "{id}" for {target.Name} (account-wide).`
	end
	return `Failed to unlock "{id}" for {target.Name}: {reason or "unknown reason"}.`
end
