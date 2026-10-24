--!strict
--[=[
	EmployeeVfxConstants: the employee's world particles (VfxBurstRegistry bursts).

	- employeeSwapGoo: changing employee or skin in the depot: a ring of glossy Gloom-purple goo puffs bursts out at
	  the character's feet and settles, with a few Gleam stars popping up through it (the "goo poof" the new look
	  steps out of). Kid-safe: no red, no light.

	@class EmployeeVfxConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxShared = ReplicatedStorage.Shared.Features.Vfx
local VfxAssets = require(VfxShared.Data.VfxAssets)
local VfxConstants = require(VfxShared.Data.VfxConstants)
local VfxFormulas = require(VfxShared.Utils.VfxFormulas)
local VfxTypes = require(VfxShared.Data.VfxTypes)

type Burst = VfxTypes.Burst

local T = VfxAssets.TEXTURES
local P = VfxConstants.PALETTE
local seq = VfxFormulas.sequence
local gradient = VfxFormulas.gradient

local PRESETS: { [string]: Burst } = {
	employeeSwapGoo = {
		layers = {
			{
				texture = T.puff,
				color = gradient({ P.pippa, P.gloomMid, P.gloom }),
				size = seq({ { 0, 1.4 }, { 0.4, 2.6 }, { 1, 3 } }),
				transparency = seq({ { 0, 0.05 }, { 0.6, 0.3 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.5, 0.8),
				speed = NumberRange.new(7, 11),
				count = 14,
				spread = Vector2.new(90, 20),
				acceleration = Vector3.new(0, -3, 0),
				drag = 6,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-60, 60),
				lightInfluence = 0.5,
			},
			{
				texture = T.star,
				color = gradient({ P.gleamLight, P.gleam }),
				size = seq({ { 0, 0 }, { 0.25, 0.8 }, { 1, 0 } }),
				transparency = seq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.6, 0.9),
				speed = NumberRange.new(6, 9),
				count = 6,
				delay = 0.1,
				spread = Vector2.new(30, 30),
				acceleration = Vector3.new(0, -8, 0),
				drag = 1,
				rotation = NumberRange.new(-20, 20),
				lightEmission = 0.5,
				lightInfluence = 0.2,
				zOffset = 1,
			},
		},
	},
}

return table.freeze({
	PRESETS = table.freeze(PRESETS),
	-- Seconds after a swapped character appears before the puff plays (the server has placed it by then).
	SWAP_SETTLE = 0.05,
})
