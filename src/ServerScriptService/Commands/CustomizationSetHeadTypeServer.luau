--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)

return function(_context, target: Player, headType: string)
	local success, reason = CustomizationService:setHeadType(target.UserId, headType)
	if success then
		return `Set {target.Name}'s head type to {headType}.`
	end
	return `Failed to set head type for {target.Name}: {reason or "unknown reason"}.`
end
