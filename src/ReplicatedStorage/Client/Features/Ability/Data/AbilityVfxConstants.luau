--!strict
--[=[
	AbilityVfxConstants: the abilities' functional world effects (VfxBurstRegistry bursts and the spot and
	plant looks). Functional on purpose: the real VFX polish is a later phase (game-vfx-design). Kid-safe: no red, no
	flash, no light. Static data (validated by VfxBurstRegistry at load).

	- abilityLetsGo (tier 2): Pippa's rally: a gold ring of stars bursting out at her feet.
	- abilityPlantPuff (tier 2): a puff of leaves and dust as Prickles becomes a plant, and again as he pops out.
	- The spot: Cappy's treasure outlined in gold through walls, with a star over it (his client only).

	@class AbilityVfxConstants
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

-- Prickles' leaf green (his UI colour) and its shade.
local LEAF = Color3.fromRGB(127, 191, 77)
local LEAF_DARK = Color3.fromRGB(64, 120, 46)

local PRESETS: { [string]: Burst } = {
	abilityLetsGo = {
		layers = {
			{
				texture = T.ring,
				color = gradient({ P.gleamLight, P.gleam }),
				size = seq({ { 0, 1 }, { 0.3, 7 }, { 1, 9 } }),
				transparency = seq({ { 0, 0.1 }, { 0.5, 0.4 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.5, 0.5),
				speed = NumberRange.new(0, 0),
				count = 1,
				orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				lightEmission = 0.4,
				lightInfluence = 0.2,
			},
			{
				texture = T.star,
				color = gradient({ P.gleamLight, P.gleam }),
				size = seq({ { 0, 0 }, { 0.2, 0.9 }, { 1, 0 } }),
				transparency = seq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.5, 0.8),
				speed = NumberRange.new(10, 14),
				count = 12,
				delay = 0.05,
				spread = Vector2.new(80, 15),
				acceleration = Vector3.new(0, -6, 0),
				drag = 3,
				rotation = NumberRange.new(-20, 20),
				lightEmission = 0.5,
				lightInfluence = 0.2,
				zOffset = 1,
			},
		},
		maxDistance = 120,
	},
	abilityPlantPuff = {
		layers = {
			{
				texture = T.puff,
				color = gradient({ P.dust, P.dustDark }),
				size = seq({ { 0, 1 }, { 0.4, 2.4 }, { 1, 2.8 } }),
				transparency = seq({ { 0, 0.1 }, { 0.6, 0.4 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.4, 0.7),
				speed = NumberRange.new(5, 8),
				count = 10,
				spread = Vector2.new(90, 15),
				acceleration = Vector3.new(0, -2, 0),
				drag = 6,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-60, 60),
				lightInfluence = 0.6,
			},
			{
				texture = T.shard,
				color = gradient({ LEAF, LEAF_DARK }),
				size = seq({ { 0, 0.5 }, { 1, 0.3 } }),
				transparency = seq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.6, 0.9),
				speed = NumberRange.new(6, 10),
				count = 8,
				delay = 0.05,
				spread = Vector2.new(60, 60),
				acceleration = Vector3.new(0, -14, 0),
				drag = 2,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-180, 180),
				lightInfluence = 0.5,
				zOffset = 1,
			},
		},
		maxDistance = 120,
	},
}

return table.freeze({
	PRESETS = table.freeze(PRESETS),
	-- Cappy's spot: the outline and fill through walls, and the star over it (studs above the item, size in studs).
	SPOT_OUTLINE = P.gleam,
	SPOT_FILL = P.gleamLight,
	SPOT_FILL_TRANSPARENCY = 0.55,
	SPOT_STAR = T.star,
	SPOT_STAR_COLOR = P.gleam,
	SPOT_STAR_SIZE = 3,
	SPOT_STAR_LIFT = 2.5,
	SPOT_NAME = "AbilitySpot",
})
