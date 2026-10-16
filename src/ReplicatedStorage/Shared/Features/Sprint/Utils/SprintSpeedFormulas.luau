--!strict
--[=[
	SprintSpeedFormulas: how fast a sprint goes (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §3).
	Empty-handed it is SPRINT_SPEED; a load slows it by exactly the factor it slows the walk, through Carry's own formula
	(CarryFormulas.carrierSpeed): sprint = SPRINT_SPEED x (carried walk speed / walk speed). Pure.

	@class SprintSpeedFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryFormulas = require(ReplicatedStorage.Shared.Features.Carry.Utils.CarryFormulas)
local SprintConstants = require(ReplicatedStorage.Shared.Features.Sprint.Data.SprintConstants)

local SprintSpeedFormulas = {}

--[=[
	The sprint speed carrying a load of `weight` (Carry's weight; nil or 0 when empty-handed).
]=]
function SprintSpeedFormulas.speed(weight: number?): number
	return CarryFormulas.carrierSpeed(SprintConstants.SPRINT_SPEED, weight or 0)
end

return SprintSpeedFormulas
