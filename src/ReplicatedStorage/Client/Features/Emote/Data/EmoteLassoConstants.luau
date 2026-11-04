--!strict
--[=[
	EmoteLassoConstants: Sheriff Prickles' bendy lasso in Big Roundup (EmoteLassoSystem, EmoteLassoFormulas): where the
	rope and loop sit on the clip-posed LassoLoop prop, and how the chain and ring move. Owner picks, 2026-11-03: a
	beam rope and a soft loop instead of the rigid hoop; the loop spins 1.5x the clip; bend limits so the rope never
	crumples; no beads on the rope. Lengths are in the LassoLoop template's units (scaled by the part's size); pulls
	are 1/s^2, so they do not scale. Tuned against the clip's own motion offline:
	characters/launch/animation-workbench/workflow/bendy-lasso-2026-11-03 (sim.py, README.md).

	@class EmoteLassoConstants
]=]

export type Tuning = {
	-- LassoLoop v3 geometry: the rope stands ropeLength above the grip; the ring's radius.
	ropeLength: number,
	ringRadius: number,
	-- Chain and ring points.
	ropePoints: number,
	ringPoints: number,
	-- Stylised gravity (units/s^2) and velocity damping (1/s).
	gravity: number,
	damping: number,
	-- Weak pulls toward the clip's pose (1/s^2): the knot, the ring next to it, the ring's far side, the rope's middle.
	pullKnot: number,
	pullNear: number,
	pullFar: number,
	pullRope: number,
	-- The wrist circle the knot rides (so the rope sweeps a cone), and how much its radius breathes.
	wrist: number,
	wristWobble: number,
	-- The outward pull that holds a spinning loop open (1/s^2).
	open: number,
	-- Rope length over the hand-to-knot distance.
	slack: number,
	-- Speed cap (units/s), so a yank never flings the chain.
	maxSpeed: number,
	-- During the throw: the knot pulled this many times harder, the rope's middle pulled this much more.
	throwKnot: number,
	throwPull: number,
	-- Constraint passes per substep, the substep (s) and the most substeps in one frame.
	iterations: number,
	substep: number,
	maxSubsteps: number,
	-- The throw: the rope tips this far toward his facing (dot) after standing up for armSeconds; the knot flies
	-- `reach` out, over throwOut, holds throwHold, and comes back over throwBack (seconds).
	tipOn: number,
	armSeconds: number,
	reach: number,
	lift: number,
	throwOut: number,
	throwHold: number,
	throwBack: number,
	-- The loop turns spinMul x the clip's rate while the rope stands up (pulls scale by spinMul^2, damping by spinMul).
	spinMul: number,
	-- Max bend (degrees) of a rope joint: the first two and the last, and the rest.
	bendEnds: number,
	bendMid: number,
	-- Points this far (template units) from their pose snap back: a teleport or a respawn.
	snapDistance: number,
}

local TUNING: Tuning = table.freeze({
	ropeLength = 2.5,
	ringRadius = 1.1,
	ropePoints = 10,
	ringPoints = 16,
	gravity = 14,
	damping = 3,
	pullKnot = 120,
	pullNear = 70,
	pullFar = 15,
	pullRope = 8,
	wrist = 0.42,
	wristWobble = 0.16,
	open = 55,
	slack = 1.06,
	maxSpeed = 70,
	throwKnot = 4,
	throwPull = 6,
	iterations = 10,
	substep = 1 / 240,
	maxSubsteps = 16,
	tipOn = 0.35,
	armSeconds = 0.5,
	reach = 1.6,
	lift = 0.4,
	throwOut = 0.12,
	throwHold = 0.12,
	throwBack = 0.16,
	spinMul = 1.5,
	bendEnds = 25,
	bendMid = 50,
	snapDistance = 8,
})

local EmoteLassoConstants = {
	-- The clip-posed prop the drawing follows (EmotePropRegistry's `swaps` for emote:Prickles.Lasso).
	PROP = "LassoLoop",
	-- The LassoLoop template's height, and its grip and knot in the part's own space (template units).
	TEMPLATE_HEIGHT = 2.62,
	GRIP = Vector3.new(1.091, -1.31, 0),
	KNOT = Vector3.new(1.091, 1.19, 0),
	TUNING = TUNING,
	-- The look: the hose's slate blue and the nozzle's brass, from the LassoLoop texture.
	HOSE = Color3.fromRGB(52, 58, 88),
	BRASS = Color3.fromRGB(201, 151, 62),
	-- Beam and ring-joint width, and the nozzle's size (template units).
	WIDTH = 0.17,
	NOZZLE = Vector3.new(0.26, 0.19, 0.19),
	-- Beam segments per rope piece and per ring piece.
	BEAM_SEGMENTS = 4,
}

return table.freeze(EmoteLassoConstants)
