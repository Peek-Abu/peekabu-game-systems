--!strict
--[=[
	OccupantDreadTracker: what the dread draws on screen this frame (the vignette, the grain and the beat's edge
	fringe; OccupantDreadSystem writes it every frame, the Dread overlay reads it every frame). Plain bookkeeping:
	nothing subscribes, so a per-frame write never re-renders React.

	@class OccupantDreadTracker
]=]

-- `vignette` and `grain` 0..1, `edge` the fringe's pulse right now (0..1), `still`: reduce motion (no grain jitter).
export type DreadFrame = {
	vignette: number,
	grain: number,
	edge: number,
	still: boolean,
}

local function empty(): DreadFrame
	return { vignette = 0, grain = 0, edge = 0, still = false }
end

local current: DreadFrame = empty()

local OccupantDreadTracker = {}

function OccupantDreadTracker.set(frame: DreadFrame)
	current = table.clone(frame)
end

function OccupantDreadTracker.get(): DreadFrame
	return current
end

function OccupantDreadTracker.clear()
	current = empty()
end

return OccupantDreadTracker
