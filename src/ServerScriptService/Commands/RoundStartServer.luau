--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local RoundService = require(ServerScriptService.Features.Round.RoundServiceServer)

return function(_context)
	if RoundService:startNow() then
		return `Round {RoundService:getPhase().round} started.`
	end
	return `A round is already {RoundService:getPhase().phase}; nothing started.`
end
