--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local TitlesService = require(ServerScriptService.Features.Title.TitleServiceServer)

return function(_context, target: Player, titleId: string)
	local ok, reason = TitlesService:equip(target.UserId, titleId)
	if ok then
		return `Equipped "{titleId}" on {target.Name}'s active character.`
	end
	return `Failed to equip "{titleId}" for {target.Name}: {reason or "unknown reason"}.`
end
