--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local TitlesService = require(ServerScriptService.Features.Title.TitleServiceServer)

return function(_context, target: Player, titleId: string)
	local ok, reason = TitlesService:revoke(target.UserId, titleId)
	if ok then
		return `Revoked "{titleId}" from {target.Name}.`
	end
	return `Failed to revoke "{titleId}" from {target.Name}: {reason or "unknown reason"}.`
end
