--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Features.Animation.AnimationServiceServer)

return function(_context, target: Player, id: string, speed: number, variant: number?)
	local ok, reason = AnimationService:play(target, id, { speed = speed, variant = variant })
	if ok then
		local variantText = if variant ~= nil then `, variant {variant}` else ""
		return `Granted "{id}" on {target.Name}'s character (speed {speed}{variantText}).`
	end
	return `Failed: {reason or "unknown reason"}.`
end
