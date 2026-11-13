--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticService = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)

return function(_context, target: Player, id: string)
	local ok, reason = CosmeticService:grantBundle(target.UserId, id)
	if ok then
		return `Unlocked bundle "{id}" for {target.Name}.`
	end
	return `Did not unlock bundle "{id}" for {target.Name}: {reason or "unknown reason"}.`
end
