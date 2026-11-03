--!strict
--[=[
	SprintSpeedFormulas: how fast a sprint goes (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §3).
	Empty-handed it is SPRINT_SPEED; a load slows it by exactly the factor it slows the walk, through Carry's own formula
	(CarryFormulas.carrierSpeed): sprint = SPRINT_SPEED x (carried walk speed / walk speed). A speed boost is one scale
	on top of every speed (WalkSpeed = plain speed x scale, always): `scaleFrom` reads it, `rescale` moves a walk from
	one scale to another. Pure.

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

--[=[
	A speed scale from an attribute's value: a positive number, else 1 (no boost).
]=]
function SprintSpeedFormulas.scaleFrom(value: unknown): number
	return if type(value) == "number" and value > 0 then value else 1
end

--[=[
	`walkSpeed` (its plain speed times `from`) at the scale `to` instead.
]=]
function SprintSpeedFormulas.rescale(walkSpeed: number, from: number, to: number): number
	return walkSpeed / from * to
end

return SprintSpeedFormulas
