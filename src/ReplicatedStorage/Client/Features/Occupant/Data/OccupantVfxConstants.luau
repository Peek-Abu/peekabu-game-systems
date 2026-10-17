--!strict
--[=[
	OccupantVfxConstants: the catch's world particles (VfxBurstRegistry bursts, played by OccupantCatchVfxSystem for
	every player who sees it). Kid-safe: porcelain and dust, no red, nothing gory.

	- occupantCatchCrack: the throw: a cartoon porcelain crack pops on the caught employee, porcelain shards scatter
	  and fall, and a puff of dust.
	- occupantRehired: back on the clock: a cream puff ring at their feet, Pippa-purple-to-gold sparkles rising and two
	  fluttering slips of rehire paperwork.

	@class OccupantVfxConstants
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
	occupantCatchCrack = {
		layers = {
			{
				texture = T.crack,
				color = gradient({ P.porcelain }),
				size = seq({ { 0, 2.4 }, { 0.12, 4.2 }, { 1, 4.5 } }),
				transparency = seq({ { 0, 0 }, { 0.6, 0 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.45),
				speed = NumberRange.new(0),
				count = 1,
				rotation = NumberRange.new(0, 360),
				lightEmission = 0.1,
				lightInfluence = 0.3,
				zOffset = 1.5,
			},
			{
				texture = T.shard,
				color = gradient({ P.porcelain, P.porcelainShade }),
				size = NumberSequence.new(0.5),
				transparency = seq({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.7, 1),
				speed = NumberRange.new(8, 13),
				count = 9,
				spread = Vector2.new(180, 180),
				acceleration = Vector3.new(0, -35, 0),
				drag = 0.5,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-420, 420),
				lightInfluence = 0.5,
				zOffset = 1,
			},
			{
				texture = T.puff,
				color = gradient({ P.porcelain, P.dust }),
				size = seq({ { 0, 1.2 }, { 1, 2.4 } }),
				transparency = seq({ { 0, 0.3 }, { 0.6, 0.5 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.8, 1.1),
				speed = NumberRange.new(3, 6),
				count = 6,
				spread = Vector2.new(180, 180),
				drag = 3,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-60, 60),
				lightInfluence = 0.5,
			},
		},
	},
	occupantRehired = {
		layers = {
			{
				texture = T.puff,
				color = gradient({ P.porcelain, P.porcelainShade }),
				size = seq({ { 0, 1 }, { 1, 2.2 } }),
				transparency = seq({ { 0, 0.15 }, { 0.5, 0.35 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.6, 0.9),
				speed = NumberRange.new(6, 9),
				count = 10,
				spread = Vector2.new(85, 85),
				acceleration = Vector3.new(0, -2, 0),
				drag = 5,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-90, 90),
				lightInfluence = 0.4,
			},
			{
				texture = T.star,
				color = gradient({ P.pippa, P.gleam }),
				size = seq({ { 0, 0 }, { 0.25, 0.7 }, { 1, 0 } }),
				transparency = seq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.7, 1),
				speed = NumberRange.new(5, 8),
				count = 8,
				delay = 0.08,
				spread = Vector2.new(35, 35),
				acceleration = Vector3.new(0, -6, 0),
				drag = 1,
				rotation = NumberRange.new(-20, 20),
				lightEmission = 0.5,
				lightInfluence = 0.2,
				zOffset = 1,
			},
			{
				texture = T.slip,
				color = gradient({ P.paper }),
				size = NumberSequence.new(0.7),
				transparency = seq({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } }),
				lifetime = NumberRange.new(1, 1.2),
				speed = NumberRange.new(6, 8),
				count = 2,
				delay = 0.1,
				spread = Vector2.new(25, 25),
				acceleration = Vector3.new(0, -10, 0),
				drag = 1.5,
				rotation = NumberRange.new(-30, 30),
				rotSpeed = NumberRange.new(-120, 120),
				squash = seq({ { 0, 0 }, { 0.5, 0.4 }, { 1, -0.2 } }),
				lightEmission = 0.1,
				lightInfluence = 0.35,
			},
		},
	},
}

return table.freeze({
	PRESETS = table.freeze(PRESETS),
	-- How long after a caught player's deadline clears their new character is waited for (the Rehired puff).
	REHIRE_WAIT = 8,
})
