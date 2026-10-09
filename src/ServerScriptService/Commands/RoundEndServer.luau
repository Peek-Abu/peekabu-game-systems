--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local RoundService = require(ServerScriptService.Features.Round.RoundServiceServer)

return function(_context, outcome: string)
	if RoundService:endRound(outcome) then
		return `Round {RoundService:getPhase().round} ended: {outcome}.`
	end
	return `No round is running (phase: {RoundService:getPhase().phase}).`
end
