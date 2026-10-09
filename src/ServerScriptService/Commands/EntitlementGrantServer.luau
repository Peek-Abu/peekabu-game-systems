--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EntitlementRegistry = require(ReplicatedStorage.Shared.Features.Entitlement.Data.EntitlementRegistry)
local EntitlementService = require(ServerScriptService.Features.Entitlement.EntitlementServiceServer)

return function(_context, target: Player, category: string, id: string)
	-- Checked here rather than left to grant()'s assert: a typo from an admin is input, not a bug.
	if not EntitlementRegistry.has(category, id) then
		return `"{category}/{id}" is not a registered entitlement.`
	end
	local ok, reason = EntitlementService:grant(target.UserId, category, id)
	if ok then
		return `Granted {category}/{id} to {target.Name}.`
	end
	return `Did not grant {category}/{id} to {target.Name}: {reason or "refused"}.`
end
