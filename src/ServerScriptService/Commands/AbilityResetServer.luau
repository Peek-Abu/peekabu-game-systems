--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local AbilityService = require(ServerScriptService.Features.Ability.AbilityServiceServer)

return function(context: { Executor: Player }, target: Player?)
	local player = target or context.Executor
	if AbilityService:resetCooldown(player) then
		return `{player.Name}'s ability is ready again.`
	end
	return `{player.Name}'s ability was already ready.`
end
