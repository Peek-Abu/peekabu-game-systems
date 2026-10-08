--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local TitlesService = require(ServerScriptService.Features.Title.TitleServiceServer)

return function(_context, target: Player, titleId: string)
	local ok, reason = TitlesService:award(target.UserId, titleId)
	if ok then
		return `Awarded "{titleId}" to {target.Name}.`
	end
	return `Failed to award "{titleId}" to {target.Name}: {reason or "unknown reason"}.`
end
