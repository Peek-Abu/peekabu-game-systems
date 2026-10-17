--!strict
--[=[
	CargoVfxConstants: the loot loop's polished particles (VfxBurstRegistry bursts, played by CargoLootFeedbackSystem
	and CargoFeedbackSystem).

	- cargoGlint: a buried pile's hint, two chunky sparkles that twinkle in and out (easy to miss on purpose).
	- cargoReveal: an item popping out of a pile: a dust puff and gold sparkles; `amount` grows with its value tier.
	- cargoAppraise: an appraisal: a few paper slips pop up off the item and flutter down, with a small paper puff.
	- cargoJackpot: a jackpot appraisal: a short gold flash, gold sparks and coins that flip and fall, with one warm
	  light; big but over in about a second.
	- cargoBankRefine: a valuable landing in the truck bed: Gloom wisps rise and turn teal, then gold (refined into
	  Gleam), then gold sparkles stream up out of the bed and a few coins pop.

	@class CargoVfxConstants
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

local function twinkle(peak: number): NumberSequence
	return seq({ { 0, 0 }, { 0.25, peak }, { 1, 0 } })
end

local HOLD_THEN_FADE = seq({ { 0, 0 }, { 0.75, 0 }, { 1, 1 } })
-- A coin flipping: its quad squashes thin and back twice over its life.
local FLIP = seq({ { 0, 0 }, { 0.2, 0.85 }, { 0.4, 0 }, { 0.6, 0.85 }, { 0.8, 0 }, { 1, 0.85 } })

local PRESETS: { [string]: Burst } = {
	cargoGlint = {
		maxDistance = 40,
		layers = {
			{
				texture = T.star,
				color = gradient({ P.gleamLight }),
				size = twinkle(0.9),
				transparency = seq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.4, 0.55),
				speed = NumberRange.new(0.2, 0.5),
				count = 2,
				spread = Vector2.new(40, 40),
				rotation = NumberRange.new(-25, 25),
				lightEmission = 0.4,
				lightInfluence = 0,
				zOffset = 0.5,
			},
		},
	},
	cargoReveal = {
		layers = {
			{
				texture = T.puff,
				color = gradient({ P.dust }),
				size = seq({ { 0, 1 }, { 1, 1.8 } }),
				transparency = seq({ { 0, 0.2 }, { 0.6, 0.45 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.5, 0.7),
				speed = NumberRange.new(4, 6),
				count = 5,
				spread = Vector2.new(80, 80),
				drag = 4,
				acceleration = Vector3.new(0, -4, 0),
				rotation = NumberRange.new(0, 360),
				lightInfluence = 0.5,
			},
			{
				texture = T.star,
				color = gradient({ P.gleamLight, P.gleam }),
				size = twinkle(0.7),
				transparency = seq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.5, 0.75),
				speed = NumberRange.new(7, 11),
				count = 8,
				spread = Vector2.new(60, 60),
				drag = 3.5,
				rotation = NumberRange.new(-20, 20),
				lightEmission = 0.35,
				lightInfluence = 0,
				zOffset = 1,
			},
		},
	},
	cargoAppraise = {
		layers = {
			{
				texture = T.slip,
				color = gradient({ P.paper }),
				size = seq({ { 0, 0.5 }, { 0.15, 0.75 }, { 1, 0.7 } }),
				transparency = HOLD_THEN_FADE,
				lifetime = NumberRange.new(0.8, 1),
				speed = NumberRange.new(6, 9),
				count = 4,
				spread = Vector2.new(35, 35),
				acceleration = Vector3.new(0, -14, 0),
				drag = 1,
				rotation = NumberRange.new(-30, 30),
				rotSpeed = NumberRange.new(-140, 140),
				squash = seq({ { 0, 0 }, { 0.5, 0.4 }, { 1, -0.2 } }),
				lightEmission = 0.1,
				lightInfluence = 0.35,
				zOffset = 0.5,
			},
			{
				texture = T.puff,
				color = gradient({ P.paper }),
				size = seq({ { 0, 0.6 }, { 1, 1.2 } }),
				transparency = seq({ { 0, 0.3 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.35, 0.45),
				speed = NumberRange.new(2, 3),
				count = 2,
				spread = Vector2.new(70, 70),
				drag = 4,
				lightInfluence = 0.4,
			},
		},
	},
	cargoJackpot = {
		light = { color = P.gleam, brightness = 3, range = 14, seconds = 0.4 },
		layers = {
			{
				-- The flash: gold, never white, gone in a fifth of a second.
				texture = T.star,
				color = gradient({ P.gleam }),
				size = seq({ { 0, 1 }, { 0.25, 4.5 }, { 1, 0 } }),
				transparency = seq({ { 0, 0.1 }, { 1, 0.6 } }),
				lifetime = NumberRange.new(0.22),
				speed = NumberRange.new(0),
				count = 1,
				lightEmission = 0.4,
				lightInfluence = 0,
				zOffset = 1.5,
			},
			{
				texture = T.star,
				color = gradient({ P.gleamLight, P.gleam, P.gleamDeep }),
				size = seq({ { 0, 0.4 }, { 0.2, 0.85 }, { 1, 0 } }),
				transparency = seq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.6, 0.9),
				speed = NumberRange.new(10, 15),
				count = 14,
				spread = Vector2.new(180, 180),
				drag = 4,
				rotation = NumberRange.new(-20, 20),
				lightEmission = 0.35,
				lightInfluence = 0,
				zOffset = 1,
			},
			{
				texture = T.coin,
				color = gradient({ P.gleam }),
				size = NumberSequence.new(0.75),
				transparency = HOLD_THEN_FADE,
				lifetime = NumberRange.new(0.9, 1.1),
				speed = NumberRange.new(9, 13),
				count = 7,
				spread = Vector2.new(40, 40),
				acceleration = Vector3.new(0, -32, 0),
				rotation = NumberRange.new(-15, 15),
				squash = FLIP,
				lightEmission = 0.3,
				lightInfluence = 0.3,
				zOffset = 0.8,
			},
		},
	},
	cargoBankRefine = {
		layers = {
			{
				-- Gloom rises out of the item and is refined: purple-black, teal, then Gleam gold.
				texture = T.wisp,
				color = gradient({ P.gloom, P.gloomEdge, P.gleam, P.gleamDeep }),
				size = seq({ { 0, 1.5 }, { 1, 0.5 } }),
				transparency = seq({ { 0, 0.1 }, { 0.8, 0.3 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.9, 1.1),
				speed = NumberRange.new(3, 5),
				count = 5,
				spread = Vector2.new(25, 25),
				acceleration = Vector3.new(0, 4, 0),
				drag = 1,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(120, 240),
				lightEmission = 0.3,
				lightInfluence = 0.3,
			},
			{
				-- The Gleam: sparkles stream up out of the bed.
				texture = T.star,
				color = gradient({ P.gleamLight, P.gleam }),
				size = twinkle(0.75),
				transparency = seq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.8, 1.1),
				speed = NumberRange.new(7, 11),
				count = 10,
				delay = 0.25,
				spread = Vector2.new(35, 35),
				acceleration = Vector3.new(0, 2, 0),
				drag = 1.5,
				rotation = NumberRange.new(-20, 20),
				lightEmission = 0.4,
				lightInfluence = 0,
				zOffset = 1,
			},
			{
				texture = T.coin,
				color = gradient({ P.gleam }),
				size = NumberSequence.new(0.55),
				transparency = HOLD_THEN_FADE,
				lifetime = NumberRange.new(0.7, 0.8),
				speed = NumberRange.new(6, 8),
				count = 3,
				delay = 0.3,
				spread = Vector2.new(30, 30),
				acceleration = Vector3.new(0, -28, 0),
				squash = FLIP,
				lightEmission = 0.3,
				lightInfluence = 0.3,
			},
		},
	},
}

return table.freeze({
	PRESETS = table.freeze(PRESETS),
	-- The reveal's particle amount by value tier (CargoLootFeedbackFormulas.revealTier).
	REVEAL_AMOUNT = table.freeze({ low = 0.6, mid = 1, high = 1.4, jackpot = 1.8 }),
})
