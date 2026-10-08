--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Features.Animation.AnimationServiceServer)

return function(_context, target: Player, idOrLayer: string)
	local ok, reason = AnimationService:stop(target, idOrLayer)
	if ok then
		return `Stopped "{idOrLayer}" on {target.Name}'s character.`
	end
	return `Failed: {reason or "unknown reason"}.`
end
