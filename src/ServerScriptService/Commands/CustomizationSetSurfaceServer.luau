--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)

-- Cmdr args cannot be genuinely absent once they carry a Default, so the two intents need distinct
-- sentinels. They are NOT the same thing, and the service cannot tell them apart on its own: a stored
-- selection is the COMPLETE state of the channel, so a nil aspect means "restore the rig's surface".
-- Keeping an aspect therefore has to be resolved HERE, against what is already stored, before the
-- write — otherwise `customizationsetsurface clothing1 Skin2 -` would set a pattern and silently wipe the texture.
local KEEP = "-"
local CLEAR = "none"

-- Resolves one aspect against the stored selection: KEEP carries it over, CLEAR drops it back to the
-- rig's authored surface, anything else is a new id.
local function resolve(value: string, stored: string?): string?
	if value == KEEP or value == "" then
		return stored
	end
	if value == CLEAR then
		return nil
	end
	return value
end

return function(_context, target: Player, channel: string, pattern: string, texture: string)
	local appearance = CustomizationService:getAppearance(target.UserId)
	local stored = if appearance then appearance.surfaces[channel] else nil

	local success, reason = CustomizationService:setSurface(
		target.UserId,
		channel,
		resolve(pattern, if stored then stored.pattern else nil),
		resolve(texture, if stored then stored.texture else nil)
	)
	if success then
		return `Restyled {channel} for {target.Name}.`
	end
	return `Failed to restyle {channel} for {target.Name}: {reason or "unknown reason"}.`
end
