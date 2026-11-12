--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local TipService = require(ServerScriptService.Features.Tip.TipServiceServer)
local TrainingService = require(ServerScriptService.Features.Training.TrainingServiceServer)

return function(context: { Executor: Player }, target: Player?)
	local player = target or context.Executor
	if not TrainingService:reset(player.UserId) then
		return `Nothing reset: {player.Name}'s save is not loaded.`
	end
	TipService:reset(player.UserId)
	return `{player.Name} is new to training again. Walk to the Training pad to play it.`
end
