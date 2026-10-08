--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)

-- Admin commands set a FREE rgb value; the palette-dye path (source = "dye") is driven by the
-- customization UI, which picks from the player's unlocked dyes.
return function(_context, target: Player, channel: string, r: number, g: number, b: number)
	local success, reason =
		CustomizationService:setBodyColor(target.UserId, channel, { source = "rgb", r = r, g = g, b = b })
	if success then
		return `Set {channel} to ({r}, {g}, {b}) for {target.Name}.`
	end
	return `Failed to set {channel} for {target.Name}: {reason or "unknown reason"}.`
end
