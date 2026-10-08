--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Features.Animation.AnimationServiceServer)

return function(_context, target: Player, class: string)
	-- Refused HERE: `protected` is protected by definition and `ambient` must never die to a combat
	-- verb. The command still exists for both so the refusal is DEMONSTRABLE, not folklore.
	if not AnimationService:validateStopClass(class) then
		return `Refused: "{class}" is not bulk-stoppable (only "attack" is — protected/ambient by design).`
	end
	local stopped = AnimationService:stopAttacks(target)
	return `Stopped {stopped} attack action(s) on {target.Name}'s character.`
end
