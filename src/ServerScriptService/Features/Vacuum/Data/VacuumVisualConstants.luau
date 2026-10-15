--!strict
--[=[
	VacuumVisualConstants: the backpack vacuum's geometry and hold tuning. The art is the uploaded template
	(ReplicatedStorage.Assets.CleanupCrew.Vacuum, built by characters/vacuum/build_backpack_vacuum.py); the pieces
	here are its graybox fallback with the same names and sizes, used when the template is missing.

	Pack pieces are in mount space: the mount is the middle of the harness pad, where the pack meets the back; +Y
	up, +Z back, +X the wearer's right. Wand pieces are placed per holder by VacuumHoldFormulas.wand (their frame
	here is only used for a static piece's offset from its parent piece). All studs as modelled on Pippa's
	authored rig; the wearer's fit scales them. Static data (spec-exempt beyond its sanity spec).

	@class VacuumVisualConstants
]=]

export type Piece = {
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	material: Enum.Material,
	transparency: number,
}

local TEAL = Color3.fromRGB(45, 145, 135)
local TEAL_DARK = Color3.fromRGB(31, 110, 102)
local IVORY = Color3.fromRGB(229, 221, 197)
local GRAPHITE = Color3.fromRGB(46, 53, 54)
local STEEL = Color3.fromRGB(175, 187, 187)
local AMBER = Color3.fromRGB(246, 192, 72)
local DUST = Color3.fromRGB(78, 62, 48)
local GLASS = Color3.fromRGB(207, 230, 232)

-- A vertical cylinder (a Part cylinder's axis is X).
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local function piece(
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?
): Piece
	return {
		name = name,
		shape = shape,
		size = size,
		frame = frame,
		color = color,
		material = material or Enum.Material.SmoothPlastic,
		transparency = transparency or 0,
	}
end

local CYL = Enum.PartType.Cylinder
local BLOCK = Enum.PartType.Block
local BALL = Enum.PartType.Ball

local backpack: { Piece } = {
	piece("CanisterBody", CYL, Vector3.new(0.56, 0.5, 0.5), CFrame.new(0, -0.02, 0.32) * UPRIGHT, TEAL),
	piece("CanisterBand", CYL, Vector3.new(0.05, 0.524, 0.524), CFrame.new(0, 0.2, 0.32) * UPRIGHT, GRAPHITE),
	piece("CanisterLid", CYL, Vector3.new(0.14, 0.48, 0.48), CFrame.new(0, 0.33, 0.32) * UPRIGHT, TEAL_DARK),
	piece("CanisterBase", CYL, Vector3.new(0.11, 0.516, 0.516), CFrame.new(0, -0.345, 0.32) * UPRIGHT, GRAPHITE),
	piece("BackPad", BLOCK, Vector3.new(0.4, 0.56, 0.08), CFrame.new(0, 0, 0.035), IVORY),
	piece("GaugeFrame", BLOCK, Vector3.new(0.17, 0.49, 0.05), CFrame.new(0, -0.03, 0.57), IVORY),
	piece("GaugeFill", BLOCK, Vector3.new(0.11, 0.42, 0.02), CFrame.new(0, -0.03, 0.602), DUST),
	piece(
		"GaugeWindow",
		BLOCK,
		Vector3.new(0.125, 0.43, 0.012),
		CFrame.new(0, -0.03, 0.62),
		GLASS,
		Enum.Material.Glass,
		0.8
	),
	piece("FullLamp", BALL, Vector3.new(0.084, 0.084, 0.084), CFrame.new(0, 0.265, 0.56), AMBER),
	piece("HoseOutlet", CYL, Vector3.new(0.12, 0.12, 0.12), CFrame.new(0.27, -0.24, 0.32), GRAPHITE),
	piece("WandHolster", BLOCK, Vector3.new(0.07, 0.12, 0.15), CFrame.new(0.285, 0.12, 0.32), GRAPHITE),
}

local wand: { Piece } = {
	piece("WandGrip", BLOCK, Vector3.new(0.124, 0.4, 0.124), CFrame.identity, GRAPHITE),
	piece("WandInlet", BLOCK, Vector3.new(0.148, 0.09, 0.148), CFrame.identity, TEAL_DARK),
	piece("WandTube", BLOCK, Vector3.new(0.08, 1, 0.08), CFrame.identity, STEEL, Enum.Material.Metal),
	piece("WandSwivel", BALL, Vector3.new(0.12, 0.12, 0.12), CFrame.identity, GRAPHITE),
	-- A wide floor nozzle (1.75x the first cut's 0.62, characters/vacuum v4).
	piece("FloorHead", BLOCK, Vector3.new(1.08, 0.085, 0.21), CFrame.identity, GRAPHITE),
	-- Relative to the floor head (its front lip).
	piece("FloorHeadLip", BLOCK, Vector3.new(1.04, 0.03, 0.035), CFrame.new(0, 0.015, -0.115), TEAL),
}

-- The graybox wand's grips (the grip contract, characters/vacuum/README.md), in their piece's space: GripUpper
-- on WandGrip 0.1 up from its centre, just under the hose inlet (the right hand); GripLower on the unit-long
-- WandTube 0.35 down from its top (the left hand): a clear hand-span apart, as Pippa's big round hands touched
-- (and read as one clap) 0.15 down. Identity rotation: +Y up the wand.
local grips = table.freeze({
	upper = table.freeze({ piece = "WandGrip", name = "GripUpper", position = Vector3.new(0, 0.1, 0) }),
	lower = table.freeze({ piece = "WandTube", name = "GripLower", position = Vector3.new(0, 0.15, 0) }),
})

-- The hose leaves the outlet outward (+X), a little down and back.
local OUTLET_AXIS = Vector3.new(0.95, -0.3, 0.1).Unit
local OUTLET_UP = (Vector3.new(0, 1, 0) - OUTLET_AXIS * OUTLET_AXIS.Y).Unit

return table.freeze({
	TEMPLATE_PATH = table.freeze({ "Assets", "CleanupCrew", "Vacuum" }),
	backpack = table.freeze(backpack),
	wand = table.freeze(wand),
	grips = grips,
	-- Where the hose leaves the pack (mount space; its X axis points out of the outlet) and where the stowed
	-- wand's grip clips on (the wand as long as in the hand, hanging upright down the pack's side beside the
	-- tail, its floor head turned along the side).
	outlet = CFrame.fromMatrix(Vector3.new(0.316, -0.279, 0.32), OUTLET_AXIS, OUTLET_UP),
	holster = CFrame.new(0.38, 0.12, 0.32),
	-- The hold (VacuumHoldFormulas.Tuning, fractions of the arm's reach): the right hand on GripUpper 0.05 reach
	-- down, 0.6 forward and 0.05 out from the right shoulder (~0.6 of the reach away: the elbow bends), out in
	-- front of the chest on the right (nearer or more inward, the wrist lay on Pippa's vest). The wand leans 50
	-- degrees forward and turns 65 degrees in toward the middle, so GripLower (the left hand, ~0.8
	-- studs lower down the wand on Pippa) lies in front of the body's
	-- middle where the left arm reaches it with its elbow out and forward. Two hands together on the grip read
	-- as a clap (user feedback); the left forearm reaching across to the right hip ran through Pippa's torso and
	-- vest (characters/qa/vacuum-v2). Measured on her meshes in the live pose: characters/qa/vacuum-v3. The
	-- floor head rides 0.06 (studs as modelled) over the floor.
	hold = table.freeze({
		down = 0.05,
		forward = 0.6,
		out = 0.05,
		angle = math.rad(50),
		yaw = math.rad(65),
		clearance = 0.06,
		minTube = 0.3,
	}),
	-- The hose Beam (studs as modelled): width; how far it bulges out of the outlet (wide while the wand is in
	-- the hand, so it loops out round the arm instead of through it; short to the stowed wand) and into the
	-- wand; its segments; and one texture tile's length (8 ribs).
	hose = table.freeze({ width = 0.13, curveHeld = 0.8, curveStowed = 0.3, curve1 = 0.24, segments = 16, tile = 0.5 }),
	-- A stock avatar's pack size (it was modelled on Pippa's authored rig, worn at 1.25x), Pippa's authored
	-- UpperTorso (the straps were modelled round it) and how deep the strap loops are.
	GENERIC_SIZE = 1.25,
	REFERENCE_TORSO = Vector3.new(0.955, 1.96, 1.006),
	STRAP_DEPTH = 0.84,
	-- Studs of tube when no holder could be measured.
	DEFAULT_TUBE = 1.2,
	-- The Tool's Grip with no measured hold: a hanging hand holds the handle square to the root.
	DEFAULT_GRIP = CFrame.Angles(-math.pi / 2, 0, 0),
})
