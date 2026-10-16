--!strict
--[=[
	NpcStrideFormulas: how fast an NPC's walk or run clip plays. A locomotion clip plants its feet at one speed at
	1x (`NpcAnimations.walkPlantedSpeed` / `runPlantedSpeed`); played at speed / plantedSpeed the feet stay planted
	whatever speed the NPC moves at (a tier's faster patrol, a slow corner). Clamped to STRIDE_MIN_RATE ..
	STRIDE_MAX_RATE; 1x when the clip names no planted speed. Pure.

	@class NpcStrideFormulas
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local NpcConstants = require(ServerScriptService.Features.Npc.Data.NpcConstants)

local NpcStrideFormulas = {}

function NpcStrideFormulas.rate(speed: number, plantedSpeed: number?): number
	if plantedSpeed == nil or plantedSpeed <= 0 then
		return 1
	end
	return math.clamp(speed / plantedSpeed, NpcConstants.STRIDE_MIN_RATE, NpcConstants.STRIDE_MAX_RATE)
end

return NpcStrideFormulas
