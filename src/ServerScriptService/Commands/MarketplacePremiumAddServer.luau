--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local MarketplaceService = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)

return function(_context, target: Player, amount: number)
	if amount <= 0 then
		return "The amount must be positive."
	end
	if MarketplaceService:getPremium(target.UserId) == nil then
		return `Failed to add premium: {target.Name}'s profile isn't loaded.`
	end
	local ok, reason = MarketplaceService:addPremium(target.UserId, amount)
	if not ok then
		return `Failed to add premium to {target.Name}: {reason or "refused"}.`
	end
	return `Added {amount} premium to {target.Name} (now {MarketplaceService:getPremium(target.UserId)}).`
end
