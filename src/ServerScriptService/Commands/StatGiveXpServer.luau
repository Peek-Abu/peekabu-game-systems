--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local StatsService = require(ServerScriptService.Features.Stat.StatServiceServer)

return function(_context, target: Player, amount: number): string
	-- addExperience asserts on non-positive/non-integer amounts (developer contract) — guard the
	-- Cmdr input here rather than letting an admin typo throw.
	if amount < 1 or amount % 1 ~= 0 then
		return `Amount must be a positive integer (got {amount}).`
	end

	local changed, leveledUp = StatsService:addExperience(target.UserId, amount)
	if not changed then
		return `{target.Name} is already at max level`
	end
	local progress = StatsService:getProgress(target.UserId)
	local level = if progress then progress.level else 0
	return if leveledUp
		then `Gave {amount} XP - {target.Name} is now level {level}!`
		else `Gave {amount} XP to {target.Name} (level {level})`
end
