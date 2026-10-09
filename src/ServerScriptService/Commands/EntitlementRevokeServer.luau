--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local EntitlementService = require(ServerScriptService.Features.Entitlement.EntitlementServiceServer)

return function(_context, target: Player, category: string, id: string)
	local ok, reason = EntitlementService:revoke(target.UserId, category, id)
	if ok then
		return `Revoked {category}/{id} from {target.Name}.`
	end
	return `Did not revoke {category}/{id} from {target.Name}: {reason or "refused"}.`
end
