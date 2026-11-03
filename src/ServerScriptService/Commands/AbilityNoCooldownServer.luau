--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local AbilityService = require(ServerScriptService.Features.Ability.AbilityServiceServer)

return function(context: { Executor: Player }, on: boolean, target: Player?)
	local player = target or context.Executor
	AbilityService:setNoCooldown(player, on)
	if on then
		return `No-cooldown mode is on for {player.Name}: their ability is always ready.`
	end
	return `No-cooldown mode is off for {player.Name}: the normal cooldown is back.`
end
