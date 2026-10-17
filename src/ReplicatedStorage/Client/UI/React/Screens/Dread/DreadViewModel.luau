--!strict
--[=[
	DreadViewModel: how the Manager's dread draws on screen (OccupantDreadTracker's frame -> the overlay's layers): a
	dark radial vignette that tightens as it grows (never fully closed: VIGNETTE_MAX), a faint film grain jittered 24
	times a second (still under reduce motion), and on the heartbeat an edge fringe: a red and a cyan copy of the
	vignette pushed apart (the chromatic split). Nil while nothing shows. Pure; tuning in OccupantConstants.DREAD.

	@class DreadViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantDreadTracker = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantDreadTracker)

local DREAD = OccupantConstants.DREAD

-- Below this nothing is drawn.
local EPSILON = 0.004
-- Grain frames per second, and how opaque the edge fringe is at a full pulse.
local GRAIN_FPS = 24
local EDGE_OPACITY = 0.55

export type Layers = {
	vignetteTransparency: number,
	-- The vignette image's size as a share of the screen (centred): > 1 pushes its dark edge off screen.
	vignetteScale: number,
	grainTransparency: number,
	-- The grain tile's offset in pixels (0..GRAIN_TILE).
	grainOffset: Vector2,
	edgeTransparency: number,
	redScale: number,
	cyanScale: number,
}

local DreadViewModel = {}

function DreadViewModel.layers(frame: OccupantDreadTracker.DreadFrame, clock: number): Layers?
	if frame.vignette < EPSILON and frame.grain < EPSILON and frame.edge < EPSILON then
		return nil
	end
	local vignette = math.clamp(frame.vignette, 0, 1)
	local edge = math.clamp(frame.edge, 0, 1)
	local tick = if frame.still then 0 else math.floor(clock * GRAIN_FPS)
	-- A cheap hash of the grain frame: a new offset each frame, the same one for the same frame.
	local x = (tick * 7919) % DREAD.GRAIN_TILE
	local y = (tick * 104729 + 37) % DREAD.GRAIN_TILE
	local base = 1 + DREAD.VIGNETTE_TIGHTEN * (1 - vignette)
	return {
		vignetteTransparency = 1 - vignette * DREAD.VIGNETTE_MAX,
		vignetteScale = base,
		grainTransparency = 1 - math.clamp(frame.grain, 0, 1) * DREAD.GRAIN_MAX,
		grainOffset = Vector2.new(x, y),
		edgeTransparency = 1 - edge * EDGE_OPACITY,
		redScale = base + DREAD.EDGE_SPREAD * edge,
		cyanScale = base - DREAD.EDGE_SPREAD * edge * 0.5,
	}
end

return DreadViewModel
