--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local StatsService = require(ServerScriptService.Features.Stat.StatServiceServer)

return function(_context, target: Player): string
	local refunded = StatsService:respec(target.UserId)
	if not refunded then
		return `{target.Name} had nothing to respec.`
	end

	local unspent = StatsService:getUnspentPoints(target.UserId)
	local main = if unspent then unspent.main else "?"
	local sub = if unspent then unspent.sub else "?"
	return `Respecced {target.Name} — unspent points now: main {main}, sub {sub}`
end
