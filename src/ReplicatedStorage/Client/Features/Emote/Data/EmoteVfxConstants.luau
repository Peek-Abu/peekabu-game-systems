--!strict
--[=[
	EmoteVfxConstants: the Legendary emotes' world effects (EmoteVfxSystem plays them on the clip's markers,
	EmoteEffectRegistry). Bubble Ride (Bubble Buddy), game-vfx-design tier 3 (a showcase moment):
	- STREAM: soap bubbles pour from the wand loop while she blows, drift forward and rise.
	- GIANT: a giant bubble grows from the wand round her whole body, floats with her (it rides LowerTorso, so the
	  clip's lift carries it), wobbles softly, sheds a few small bubbles.
	- emoteBubblePop: the giant bubble pops: a ring snaps out, droplet bubbles spray and fall, a few Gleam stars, and
	  one soft lilac light for 0.25 s (the tier 3 allowance).
	- emoteBubbleLand: she lands in a little splash of bubbles.
	Big Roundup (Sheriff Prickles), the same tier: dust (work family, ground-hugging browns) and one tumbleweed.
	- emoteLassoPuff: the coil shaking out into the loop, and the yank; emoteLassoThrow: dust thrown after the loop.
	- DUST_SWIRL: a ring of dust trailing under the overhead spin. emoteTumbleweed: one tumbleweed rolls by.
	Bubbles are round and light (the safe/round family): lilac, pink and Gleam gold over a clear body, no teal, nothing
	red. Textures: characters/qa/vfx/textures/bubble/make_bubble_tex.py, uploaded to Icey Labs (these are the Image ids
	behind the Decals; the Decal ids are in that folder's upload.log).

	@class EmoteVfxConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxShared = ReplicatedStorage.Shared.Features.Vfx
local VfxAssets = require(VfxShared.Data.VfxAssets)
local VfxConstants = require(VfxShared.Data.VfxConstants)
local VfxFormulas = require(VfxShared.Utils.VfxFormulas)
local VfxTypes = require(VfxShared.Data.VfxTypes)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

type Burst = VfxTypes.Burst

local T = VfxAssets.TEXTURES
local P = VfxConstants.PALETTE
local seq = VfxFormulas.sequence
local gradient = VfxFormulas.gradient

local PINK = Color3.fromRGB(240, 150, 214)

local TEXTURES = table.freeze({
	-- A clear bubble, white on alpha: fresnel body, a grey rim line, a highlight crescent (tinted per emitter).
	bubbleSmall = "rbxassetid://82581250934718",
	-- The giant bubble's face: full colour, an iridescent grape -> pink -> deep gold rim and the highlight.
	bubbleGiant = "rbxassetid://82524022477709",
	-- A round tangle of dry twigs, full colour (dust browns) with an ink edge (characters/qa/vfx/textures/lasso).
	tumbleweed = "rbxassetid://71823843488348",
})

local BUBBLE_TINT = gradient({ P.pippa, PINK, P.gleamLight, P.porcelainShade })

local PRESETS: { [string]: Burst } = {
	emoteBubblePop = {
		layers = {
			{
				texture = T.ring,
				color = gradient({ P.porcelain, P.pippa }),
				size = seq({ { 0, 2 }, { 0.3, 6.5 }, { 1, 7.5 } }),
				transparency = seq({ { 0, 0.1 }, { 0.5, 0.5 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.3, 0.3),
				speed = NumberRange.new(0, 0),
				count = 1,
				lightInfluence = 0,
				orientation = Enum.ParticleOrientation.FacingCamera,
			},
			{
				texture = TEXTURES.bubbleSmall,
				color = BUBBLE_TINT,
				size = seq({ { 0, 0.25 }, { 0.3, 0.45 }, { 1, 0.1 } }),
				transparency = seq({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.5, 0.9),
				speed = NumberRange.new(12, 18),
				count = 26,
				spread = Vector2.new(180, 180),
				acceleration = Vector3.new(0, -12, 0),
				drag = 2,
				rotation = NumberRange.new(0, 360),
				lightInfluence = 0,
			},
			{
				texture = T.star,
				color = gradient({ P.gleamLight, P.gleam }),
				size = seq({ { 0, 0 }, { 0.25, 0.7 }, { 1, 0 } }),
				transparency = seq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.5, 0.7),
				speed = NumberRange.new(6, 10),
				count = 8,
				delay = 0.04,
				spread = Vector2.new(180, 180),
				acceleration = Vector3.new(0, -6, 0),
				drag = 1,
				rotation = NumberRange.new(-20, 20),
				lightEmission = 0.5,
				lightInfluence = 0.2,
				zOffset = 1,
			},
		},
		light = { color = Color3.fromRGB(226, 212, 255), brightness = 3, range = 12, seconds = 0.25 },
	},
	emoteLassoPuff = {
		layers = {
			{
				texture = T.puff,
				color = gradient({ P.dust, P.dustDark }),
				size = seq({ { 0, 0.6 }, { 0.4, 1.3 }, { 1, 1.6 } }),
				transparency = seq({ { 0, 0.1 }, { 0.6, 0.35 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.4, 0.6),
				speed = NumberRange.new(4, 7),
				count = 8,
				spread = Vector2.new(180, 180),
				drag = 5,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-60, 60),
				lightInfluence = 0.6,
			},
		},
	},
	emoteLassoThrow = {
		layers = {
			{
				texture = T.puff,
				color = gradient({ P.dust, P.dustDark }),
				-- small and quick: it flies toward a front camera and must not cover him
				size = seq({ { 0, 0.3 }, { 0.5, 0.7 }, { 1, 0.85 } }),
				transparency = seq({ { 0, 0.3 }, { 0.5, 0.55 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.25, 0.4),
				speed = NumberRange.new(10, 14),
				count = 7,
				spread = Vector2.new(18, 18),
				direction = Enum.NormalId.Front,
				drag = 6,
				rotation = NumberRange.new(0, 360),
				lightInfluence = 0.6,
			},
		},
	},
	-- One tumbleweed rolling across in front of him (the burst is played facing its travel direction).
	emoteTumbleweed = {
		layers = {
			{
				texture = TEXTURES.tumbleweed,
				color = ColorSequence.new(Color3.new(1, 1, 1)),
				size = seq({ { 0, 1.5 }, { 1, 1.5 } }),
				transparency = seq({ { 0, 1 }, { 0.08, 0 }, { 0.85, 0 }, { 1, 1 } }),
				lifetime = NumberRange.new(2.2, 2.2),
				speed = NumberRange.new(5.5, 5.5),
				count = 1,
				direction = Enum.NormalId.Front,
				rotation = NumberRange.new(0, 0),
				rotSpeed = NumberRange.new(-260, -260),
				lightInfluence = 0.6,
			},
		},
		maxDistance = 120,
	},
	emoteBubbleLand = {
		layers = {
			{
				texture = TEXTURES.bubbleSmall,
				color = BUBBLE_TINT,
				size = seq({ { 0, 0.2 }, { 0.3, 0.38 }, { 1, 0.05 } }),
				transparency = seq({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.5, 0.8),
				speed = NumberRange.new(5, 8),
				count = 14,
				spread = Vector2.new(70, 70),
				acceleration = Vector3.new(0, -6, 0),
				drag = 2,
				rotation = NumberRange.new(0, 360),
				lightInfluence = 0,
			},
			{
				texture = T.ring,
				color = gradient({ P.porcelain, P.pippa }),
				size = seq({ { 0, 0.5 }, { 0.4, 2.6 }, { 1, 3 } }),
				transparency = seq({ { 0, 0.2 }, { 1, 1 } }),
				lifetime = NumberRange.new(0.35, 0.35),
				speed = NumberRange.new(0, 0),
				count = 1,
				lightInfluence = 0,
				orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			},
		},
	},
}

export type SoundCue = { sound: string, after: number, start: number? }

-- `speed`: a fixed PlaybackSpeed, to fit a sound to the moment it plays over.
local function library(assetId: string, volume: number, speed: number?): SoundTypes.SoundDef
	return {
		assetId = assetId,
		group = "SFX",
		bus = "Action",
		volume = volume,
		rollOffMaxDistance = 50,
		pitch = if speed ~= nil then { min = speed, max = speed } else nil,
	}
end

-- Named for their library titles. Volumes put each one's peak near 120 (PlaybackLoudness x Volume, measured in Studio
-- 2026-11-03; a step of Pippa's peaks at 153 in game): the files themselves peak from 13 (the tea sip) to 673 (the rope).
local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	mugQuieterAtTail8 = library("rbxassetid://9117037749", 1.5),
	teaSip2 = library("rbxassetid://9119956292", 8),
	-- The inflate (owner, 2026-11-03: "I dont hear a bubble inflate sound!"): its sound runs 0.96 s and swells to its end,
	-- so at 1.2x it lasts the bubble's 0.8 s growth. Its file peaks at 57.
	slideWhistle6 = library("rbxassetid://9119198150", 2.1, 1.2),
	bubbleWobbleComicBloops4 = library("rbxassetid://9112752910", 0.6),
	bubbleBloopHighPitchedCute6 = library("rbxassetid://9112751731", 0.9),
	-- Kept subtle (peaks near 47): the owner has turned down cloth sounds before. Drop lassoCoilSound to remove it.
	clothMovement24 = library("rbxassetid://9113824230", 1.2),
	woodWhooshQuickSwings4 = library("rbxassetid://9120972321", 1),
	buggyWhipLightCrack6 = library("rbxassetid://9113611449", 1.2),
	ropeImpacts4 = library("rbxassetid://9118717475", 0.2),
}

local SOUND_CUES: { [string]: { SoundCue } } = {
	-- Cocoa Sip, from PropsShow (0.233 s): the mug as it appears, the sip as it reaches his mouth (1.2 s).
	-- start = where the file's sound begins (its lead-in, measured): the sip starts 0.19 s into its file.
	cocoaSounds = { { sound = "mugQuieterAtTail8", after = 0 }, { sound = "teaSip2", after = 0.967, start = 0.17 } },
	-- Bubble Ride: from BubbleGrow, the inflate while the bubble grows, then the wobble once it is full (its growth,
	-- GIANT.growSeconds, later); the bloop on BubblePop.
	bubbleGrowSound = {
		{ sound = "slideWhistle6", after = 0, start = 0.04 },
		{ sound = "bubbleWobbleComicBloops4", after = 0.8 },
	},
	bubblePopSound = { { sound = "bubbleBloopHighPitchedCute6", after = 0 } },
	-- Big Roundup: the coil off his hip (PropsShow 0.367 s), a whoosh as the loop shakes out (LoopOut 0.9 s) and on
	-- each of its two turns overhead (DustSwirl 1.167 s; the turns pass the front at 1.25 s and 2.09 s, from the clip's
	-- prop timeline), the crack on the throw, the rope pulled tight on the yank.
	lassoCoilSound = { { sound = "clothMovement24", after = 0, start = 0.25 } },
	lassoShakeSound = { { sound = "woodWhooshQuickSwings4", after = 0, start = 0.03 } },
	lassoSpinSound = {
		{ sound = "woodWhooshQuickSwings4", after = 0.083, start = 0.03 },
		{ sound = "woodWhooshQuickSwings4", after = 0.923, start = 0.03 },
	},
	lassoCrackSound = { { sound = "buggyWhipLightCrack6", after = 0, start = 0.04 } },
	-- Rope Impacts 4 is silent for its first 0.68 s.
	lassoYankSound = { { sound = "ropeImpacts4", after = 0, start = 0.66 } },
}

return table.freeze({
	TEXTURES = TEXTURES,
	PRESETS = table.freeze(PRESETS),
	-- The wand stream: an emitter at the wand loop (the loop sits LOOP_HEIGHT of the wand part's height above its
	-- centre, along the part's Y), thinned to rateLow on low graphics.
	STREAM = table.freeze({
		texture = TEXTURES.bubbleSmall,
		color = BUBBLE_TINT,
		size = seq({ { 0, 0.2 }, { 0.2, 0.6 }, { 1, 0.75 } }),
		transparency = seq({ { 0, 0.05 }, { 0.8, 0.15 }, { 1, 1 } }),
		lifetime = NumberRange.new(1.6, 2.4),
		speed = NumberRange.new(3.5, 6),
		spread = Vector2.new(22, 22),
		acceleration = Vector3.new(0, 1.4, 0),
		drag = 1.2,
		rotSpeed = NumberRange.new(-40, 40),
		rateHigh = 24,
		rateLow = 10,
		loopHeight = 0.364,
	}),
	-- The giant bubble, at the template's size (times the character's scale): a ForceField-material ball for the
	-- 3D shimmer and a camera-facing billboard of the bubble face for the cartoon read.
	GIANT = table.freeze({
		texture = TEXTURES.bubbleGiant,
		diameter = 6.4,
		-- Its centre above LowerTorso.
		lift = 1.05,
		growSeconds = 0.8,
		-- Scale wobble (a share of the diameter) and its period, while it floats.
		wobble = 0.035,
		wobblePeriod = 1.1,
		shimmer = Color3.fromRGB(206, 178, 255),
		-- Small bubbles shed from its skin while it floats (per second; low graphics thins them).
		shedRate = 5,
	}),
	BUBBLE_TINT = BUBBLE_TINT,
	-- Bubble Buddy's fidget (owner, 2026-11-03: bubbles, but light; sparkle is for rare moments): STREAM's look at a
	-- third of its rate or less and smaller bubbles.
	LIGHT_STREAM = table.freeze({
		rateHigh = 7,
		rateLow = 3,
		sizeScale = 0.7,
	}),
	-- Cocoa Sip's steam (owner, 2026-11-03: "a few small warm steam wisps", subtle): game-vfx-design tier 0, an emitter
	-- just above the mug's rim while the mug is out. Warm cream curls (the Gloom wisp texture, tinted), rising slowly,
	-- see-through, no glow. Sizes at the template's size (times the character's scale); `rimHeight` is the share of
	-- the mug part's height above its centre where the wisps start.
	STEAM = table.freeze({
		texture = T.wisp,
		color = gradient({ P.porcelain, Color3.fromRGB(240, 222, 200) }),
		size = seq({ { 0, 0.12 }, { 0.4, 0.3 }, { 1, 0.42 } }),
		transparency = seq({ { 0, 1 }, { 0.2, 0.55 }, { 0.6, 0.7 }, { 1, 1 } }),
		lifetime = NumberRange.new(1.2, 1.6),
		speed = NumberRange.new(0.35, 0.7),
		spread = Vector2.new(12, 12),
		acceleration = Vector3.new(0, 0.5, 0),
		drag = 0.8,
		rotSpeed = NumberRange.new(-35, 35),
		lightEmission = 0,
		rateHigh = 3,
		rateLow = 2,
		rimHeight = 0.5,
	}),
	-- Big Roundup's dust ring: an emitter orbiting his feet while the loop spins, leaving a circle of dust.
	DUST_SWIRL = table.freeze({
		texture = T.puff,
		color = gradient({ P.dust, P.dustDark }),
		size = seq({ { 0, 0.5 }, { 0.4, 1.1 }, { 1, 1.4 } }),
		transparency = seq({ { 0, 0.2 }, { 0.6, 0.45 }, { 1, 1 } }),
		lifetime = NumberRange.new(0.6, 0.9),
		speed = NumberRange.new(0.5, 1.5),
		-- Studs from his feet (times his scale), turns per second, studs above the ground.
		radius = 1.4,
		turns = 1.5,
		height = 0.25,
		rateHigh = 20,
		rateLow = 8,
	}),
	-- The tumbleweed starts this far (times his scale) to his left and rolls past to his right, at this height.
	TUMBLEWEED = table.freeze({ from = 6, height = 0.75 }),
	-- The Legendary emotes' sounds: Roblox library sounds (ProSoundEffects; they play in place, no upload), the owner's
	-- picks of 2026-11-03. SOUND_CUES[effect id] = what plays when that effect starts (EmoteEffectRegistry names the
	-- marker): each `sound` (a SOUNDS key) `after` seconds, from `start` seconds into its file (a library file's lead-in,
	-- measured in Studio). A clip cut short cancels what has not started and fades what plays over SOUND_FADE.
	SOUNDS = SOUNDS,
	SOUND_CUES = SOUND_CUES,
	SOUND_FADE = 0.3,
})
