--!strict
--[=[
	CrouchSpeedFormulas: how fast a crouch goes. Empty-handed it is CROUCH_SPEED; a load slows it by exactly the factor
	it slows the walk, through Carry's own formula (the SprintSpeedFormulas precedent): crouch = CROUCH_SPEED x (carried
	walk speed / walk speed). Pure.

	@class CrouchSpeedFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryFormulas = require(ReplicatedStorage.Shared.Features.Carry.Utils.CarryFormulas)
local CrouchConstants = require(ReplicatedStorage.Shared.Features.Crouch.Data.CrouchConstants)

local CrouchSpeedFormulas = {}

--[=[
	The crouch speed carrying a load of `weight` (Carry's weight; nil or 0 when empty-handed).
]=]
function CrouchSpeedFormulas.speed(weight: number?): number
	return CarryFormulas.carrierSpeed(CrouchConstants.CROUCH_SPEED, weight or 0)
end

return CrouchSpeedFormulas
