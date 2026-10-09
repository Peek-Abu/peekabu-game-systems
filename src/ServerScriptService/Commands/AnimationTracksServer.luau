--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Features.Animation.AnimationServiceServer)

return function(_context, target: Player)
	AnimationService:requestTrackReport(target)
	return `Track report requested — read {target.Name}'s client log (F4 → Logs, client context) or the Animations panel.`
end
