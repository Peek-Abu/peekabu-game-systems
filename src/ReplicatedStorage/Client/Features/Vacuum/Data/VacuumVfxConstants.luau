--!strict
--[=[
	VacuumVfxConstants: the vacuum's polished particles (VfxBurstRegistry bursts, played by VacuumVfxSystem). Sizes are
	for a standard 4 x 1 x 4 pile at scale 1 (REFERENCE_SIZE across); a pile's pop is scaled by its own size.

	- vacuumSuction (funnel): dust puffs and Gloom wisps (purple-black, turning teal at the nozzle) spiralling from the
	  pile into the floor head, the rate and spin rising with the suction's strength.
	- vacuumGrimeSuction (funnel): grime flakes and a few wisps peeling off a valuable into the floor head.
	- vacuumPuff: a little dust cough off the pile each PUFF_STEP of progress, so it visibly shrinks in puffs.
	- vacuumPop: the pile clearing: a ground-hugging dust ring, one short pop ring, the last Gloom escaping and a few
	  clean sparkles (24 particles at most).
	- vacuumShine / vacuumShineSparkle: a valuable coming up spotless: a diagonal shine sweep across it; a twinkle and
	  the last grime flakes at its centre.

	@class VacuumVfxConstants
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

-- Fade in quickly, hold, fade out: most layers.
local SOFT = seq({ { 0, 1 }, { 0.12, 0.15 }, { 0.75, 0.3 }, { 1, 1 } })
-- A twinkle: grows in, shrinks out (a size curve, scaled per layer).
local function twinkle(peak: number): NumberSequence
	return seq({ { 0, 0 }, { 0.25, peak }, { 1, 0 } })
end

local PRESETS: { [string]: Burst } = {
	vacuumSuction = {
		maxDistance = 120,
		layers = {
			{
				texture = T.puff,
				color = gradient({ P.dust, P.dustDark }),
				size = seq({ { 0, 1 }, { 0.6, 0.75 }, { 1, 0.15 } }),
				transparency = SOFT,
				lifetime = NumberRange.new(0.55),
				speed = NumberRange.new(1),
				rate = 30,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-120, 120),
				lightInfluence = 0.5,
			},
			{
				texture = T.wisp,
				color = gradient({ P.gloom, P.gloomMid, P.gloomEdge }),
				size = seq({ { 0, 1.5 }, { 0.7, 0.9 }, { 1, 0.25 } }),
				transparency = seq({ { 0, 1 }, { 0.15, 0.1 }, { 0.8, 0.25 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.6),
				speed = NumberRange.new(1),
				rate = 14,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(180, 320),
				lightEmission = 0.15,
				lightInfluence = 0.6,
				zOffset = 0.2,
			},
		},
	},
	vacuumGrimeSuction = {
		maxDistance = 120,
		layers = {
			{
				texture = T.shard,
				color = gradient({ P.grime, P.gloomMid }),
				size = seq({ { 0, 0.45 }, { 1, 0.15 } }),
				transparency = SOFT,
				lifetime = NumberRange.new(0.55),
				speed = NumberRange.new(1),
				rate = 22,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-600, 600),
			},
			{
				texture = T.wisp,
				color = gradient({ P.gloom, P.gloomEdge }),
				size = seq({ { 0, 1 }, { 1, 0.2 } }),
				transparency = seq({ { 0, 1 }, { 0.2, 0.2 }, { 0.8, 0.35 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.6),
				speed = NumberRange.new(1),
				rate = 8,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(180, 300),
				lightEmission = 0.15,
				lightInfluence = 0.6,
			},
		},
	},
	vacuumPuff = {
		maxDistance = 100,
		layers = {
			{
				texture = T.puff,
				color = gradient({ P.dust }),
				size = seq({ { 0, 0.8 }, { 1, 1.6 } }),
				transparency = seq({ { 0, 0.25 }, { 0.6, 0.45 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.5, 0.7),
				speed = NumberRange.new(2, 4),
				count = 3,
				spread = Vector2.new(55, 55),
				acceleration = Vector3.new(0, -2, 0),
				drag = 3,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-60, 60),
				lightInfluence = 0.5,
			},
		},
	},
	vacuumPop = {
		layers = {
			{
				-- The dust ring: out along the floor and settling.
				texture = T.puff,
				color = gradient({ P.dust, P.dustDark }),
				size = seq({ { 0, 1 }, { 1, 1.9 } }),
				transparency = seq({ { 0, 0.15 }, { 0.5, 0.4 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.6, 0.8),
				speed = NumberRange.new(7, 10),
				count = 9,
				spread = Vector2.new(85, 85),
				acceleration = Vector3.new(0, -10, 0),
				drag = 5,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-90, 90),
				lightInfluence = 0.5,
			},
			{
				-- The pop: one short ring, gone in a quarter second.
				texture = T.ring,
				color = gradient({ P.gloomEdge }),
				size = seq({ { 0, 0.6 }, { 1, 2.8 } }),
				transparency = seq({ { 0, 0.15 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.25),
				speed = NumberRange.new(0),
				count = 1,
				lightEmission = 0.6,
				lightInfluence = 0,
				zOffset = 0.5,
			},
			{
				-- The last of the Gloom escapes, purple-black to teal.
				texture = T.wisp,
				color = gradient({ P.gloom, P.gloomMid, P.gloomEdge }),
				size = seq({ { 0, 0.9 }, { 1, 0.3 } }),
				transparency = seq({ { 0, 0.1 }, { 0.7, 0.35 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.7, 0.9),
				speed = NumberRange.new(3, 5),
				count = 4,
				spread = Vector2.new(30, 30),
				acceleration = Vector3.new(0, 3, 0),
				drag = 1.5,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-200, 200),
				lightEmission = 0.15,
				lightInfluence = 0.6,
			},
			{
				-- Clean sparkles.
				texture = T.star,
				color = gradient({ P.sparkle, P.gloomEdge }),
				size = twinkle(0.75),
				transparency = seq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.5, 0.8),
				speed = NumberRange.new(4, 7),
				count = 6,
				delay = 0.05,
				spread = Vector2.new(70, 70),
				drag = 3,
				rotation = NumberRange.new(-20, 20),
				lightEmission = 0.7,
				lightInfluence = 0,
				zOffset = 1,
			},
		},
	},
	vacuumShine = {
		layers = {
			{
				-- The sweep: one diagonal shine bar sliding across (emitted along the CFrame's +Y, its screen right).
				texture = T.streak,
				color = gradient({ P.gleamLight }),
				size = seq({ { 0, 1.6 }, { 0.5, 3 }, { 1, 1.6 } }),
				transparency = seq({ { 0, 1 }, { 0.2, 0.05 }, { 0.8, 0.2 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.35),
				speed = NumberRange.new(7),
				count = 1,
				rotation = NumberRange.new(60),
				lightEmission = 0.8,
				lightInfluence = 0,
				zOffset = 3,
			},
		},
	},
	vacuumShineSparkle = {
		layers = {
			{
				texture = T.star,
				color = gradient({ P.gleamLight, P.sparkle }),
				size = twinkle(0.8),
				transparency = seq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.5, 0.7),
				speed = NumberRange.new(0.5, 1.5),
				count = 4,
				delay = 0.15,
				spread = Vector2.new(180, 180),
				rotation = NumberRange.new(-20, 20),
				lightEmission = 0.8,
				lightInfluence = 0,
				zOffset = 1,
			},
			{
				-- The last grime flakes pop off and fall.
				texture = T.shard,
				color = gradient({ P.grime, P.gloomMid }),
				size = seq({ { 0, 0.32 }, { 1, 0.2 } }),
				transparency = seq({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.6, 0.8),
				speed = NumberRange.new(3, 5),
				count = 6,
				spread = Vector2.new(60, 60),
				acceleration = Vector3.new(0, -25, 0),
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-400, 400),
			},
		},
	},
}

return table.freeze({
	PRESETS = table.freeze(PRESETS),
	-- The size (studs across, the base size's magnitude) the presets are drawn for: a standard 4 x 1 x 4 pile.
	REFERENCE_SIZE = Vector3.new(4, 1, 4).Magnitude,
	-- A dust puff off the pile every this much channel progress.
	PUFF_STEP = 0.15,
	-- The pop's scale stays within these bounds, so a tiny or huge pile still reads.
	POP_SCALE_MIN = 0.6,
	POP_SCALE_MAX = 1.6,
})
