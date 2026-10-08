--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StatsService = require(ServerScriptService.Features.Stat.StatServiceServer)
local StatConstants = require(ReplicatedStorage.Shared.Features.Stat.Data.StatConstants)

-- `statId` is a custom Cmdr arg type (see AdminServiceServer), so Cmdr only ever passes a validated
-- stat id — the param is a real StatId, no cast needed.
return function(_context, target: Player, statId: StatConstants.StatId, points: number): string
	local ok, reason = StatsService:invest(target.UserId, statId, points)
	if not ok then
		return `Could not invest for {target.Name}: {reason or "unknown reason"}`
	end

	local definition = StatConstants.DEFINITIONS[statId]
	local unspent = StatsService:getUnspentPoints(target.UserId)
	local remaining = if unspent and definition then unspent[definition.pool] else nil
	return `Invested {points} point(s) into {statId} for {target.Name} ({remaining or "?"} unspent remaining in {if definition
		then definition.pool
		else "?"})`
end
