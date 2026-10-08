--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)
local CustomizationSoulColorRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationSoulColorRegistry)

-- Cmdr args carrying a Default cannot be genuinely absent, so "-" marks an unsupplied hue.
local UNSET = "-"

return function(_context, target: Player, hue1: string, hue2: string, hue3: string)
	local hues: { string } = {}
	for _, hue in { hue1, hue2, hue3 } do
		if hue ~= UNSET and hue ~= "" then
			table.insert(hues, hue)
		end
	end
	-- Joined in the order given: hue order is significant, since it decides the gradient direction.
	-- No hues at all means CLEAR: the service takes nil for that, and joining nothing would otherwise
	-- produce "", which is not a registered id and would fail instead of clearing.
	local colorId = if #hues > 0 then table.concat(hues, CustomizationSoulColorRegistry.HUE_SEPARATOR) else nil

	local success, reason = CustomizationService:setSoulColor(target.UserId, colorId)
	if success then
		if colorId == nil then
			return `Cleared {target.Name}'s soul colour.`
		end
		return `Set {target.Name}'s soul colour to {colorId}.`
	end
	return `Failed to set soul colour for {target.Name}: {reason or "unknown reason"}.`
end
