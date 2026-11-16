--!strict
--[=[
	AnimationVacuumLayerHarness: the motion layers the vacuum hold validator (AnimationVacuumHarness) lays on every
	frame, each at its extremes (VacuumMotionFormulas.Layers): rest, the aims, the brace, the pop's recoil and rebound,
	the shimmy, the wand's sway, the look each way, and all at once. Split out of AnimationVacuumHarness.

	@class AnimationVacuumLayerHarness
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumMotionConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)
local VacuumMotionFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumMotionFormulas)

local AnimationVacuumLayerHarness = {}

-- Each motion layer at its extremes (VacuumMotionFormulas.Layers), laid on every frame.
-- A layers' state: every layer off but those given (the shimmy as a fraction of its amplitude, each way).
type Given = {
	raise: number?,
	reach: number?,
	brace: number?,
	kick: number?,
	shimmy: number?,
	swayYaw: number?,
	swayPitch: number?,
	-- The look's heading off the body (radians, left positive): the wand aims at it, the upper body twists toward it.
	look: number?,
}
local function layered(given: Given): VacuumMotionFormulas.Layers
	local shimmy = given.shimmy or 0
	return {
		raise = given.raise or 0,
		reach = given.reach or 0,
		brace = given.brace or 0,
		kick = given.kick or 0,
		shimmyYaw = shimmy * VacuumMotionConstants.shimmy.yaw,
		shimmyRoll = shimmy * VacuumMotionConstants.shimmy.roll,
		swayYaw = given.swayYaw or 0,
		swayPitch = given.swayPitch or 0,
		lookYaw = given.look or 0,
	}
end
local UP = VacuumMotionConstants.aim.maxUp
-- The biggest kick (a pile at maxScale, at its peak).
local KICK = VacuumMotionConstants.kick.maxScale
local SWAY_YAW = VacuumMotionConstants.sway.maxYaw
local SWAY_PITCH = VacuumMotionConstants.sway.maxPitch
local LOOK = VacuumMotionConstants.aim.maxLook
local LAYERS: { { name: string, layers: VacuumMotionFormulas.Layers } } = {
	{ name = "rest", layers = layered({}) },
	{ name = "aim up", layers = layered({ raise = UP }) },
	{ name = "aim out", layers = layered({ reach = 1 }) },
	{ name = "aim in", layers = layered({ reach = -1 }) },
	{ name = "brace", layers = layered({ brace = 1 }) },
	{ name = "brace+out", layers = layered({ reach = 1, brace = 1 }) },
	{ name = "brace+in", layers = layered({ reach = -1, brace = 1 }) },
	{ name = "brace+up", layers = layered({ raise = UP, brace = 1 }) },
	-- The pop: the kick's peak, and the spring's rebound the other way.
	{ name = "recoil", layers = layered({ brace = 1, kick = KICK }) },
	{ name = "recoil back", layers = layered({ reach = 1, brace = 1, kick = -0.4 * KICK }) },
	{ name = "recoil+up", layers = layered({ raise = UP, kick = KICK }) },
	-- The shimmy at its full amplitude, each way.
	{ name = "shimmy+", layers = layered({ reach = 1, brace = 1, shimmy = 1 }) },
	{ name = "shimmy-", layers = layered({ brace = 1, shimmy = -1 }) },
	-- The wand's lag at its most: swung each way on a turn, slid on at a stop, trailing while aimed up.
	{ name = "sway left", layers = layered({ swayYaw = SWAY_YAW }) },
	{ name = "sway right", layers = layered({ swayYaw = -SWAY_YAW, reach = 1 }) },
	{ name = "sway stop", layers = layered({ swayPitch = SWAY_PITCH, swayYaw = SWAY_YAW }) },
	{ name = "sway+up", layers = layered({ raise = UP, swayPitch = -SWAY_PITCH, swayYaw = -SWAY_YAW }) },
	-- Aimed at the look point at its most each way (aim fix 2026-11-06: the floor head points at it, the upper
	-- body twists toward it), and braced.
	{ name = "aim left", layers = layered({ look = LOOK }) },
	{ name = "aim right", layers = layered({ look = -LOOK }) },
	{ name = "brace+left", layers = layered({ look = LOOK, brace = 1 }) },
	{ name = "brace+right", layers = layered({ look = -LOOK, brace = 1, reach = 1 }) },
	-- Everything at once.
	{
		name = "all",
		layers = layered({ raise = UP, brace = 1, kick = KICK, shimmy = 1, swayYaw = SWAY_YAW, swayPitch = SWAY_PITCH }),
	},
}

AnimationVacuumLayerHarness.LAYERS = LAYERS

return AnimationVacuumLayerHarness
