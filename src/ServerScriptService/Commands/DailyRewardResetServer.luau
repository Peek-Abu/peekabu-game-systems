--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local DailyRewardService = require(ServerScriptService.Features.DailyReward.DailyRewardServiceServer)

return function(_context, target: Player)
	if DailyRewardService:reset(target.UserId) then
		return `Cleared {target.Name}'s daily reward streak.`
	end
	return `Nothing to clear for {target.Name} (no streak, or the profile isn't loaded).`
end
