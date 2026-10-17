--!strict
--[=[
	FootstepTypes: the types the Footstep feature shares. Types only (spec-exempt).

	@class FootstepTypes
]=]

-- What a step lands on (FootstepSurfaceUtils.surfaceFor). `default` is every floor not named here.
export type Surface = "default" | "carpet" | "tile" | "wood" | "concrete"

-- How the character moves (FootstepGaitFormulas.gaitFor).
export type Gait = "walk" | "sprint" | "crouch" | "hidden"

-- Multipliers on the set's volume and on each play's picked pitch.
export type GaitScale = {
	volume: number,
	pitch: number,
}

-- The four gaits' scales.
export type GaitScales = {
	walk: GaitScale,
	sprint: GaitScale,
	crouch: GaitScale,
	hidden: GaitScale,
}

-- One list of strings per surface (asset ids in FootstepAssets.SETS, sound names in FootstepAssets.SOUND_IDS).
export type SurfacePools = {
	default: { string },
	carpet: { string },
	tile: { string },
	wood: { string },
	concrete: { string },
}

-- One character's footsteps (FootstepAssets.SETS): the sound and its variant pools per surface.
export type FootstepSet = {
	-- Sound.Volume of a walking step (0..10), before the gait scale.
	volume: number,
	-- Each step picks a PlaybackSpeed in this range (the per-step pitch jitter), before the gait scale.
	pitch: { min: number, max: number },
	-- Studs at which a step is inaudible.
	rollOffMaxDistance: number,
	-- The walk's and the run's speeds (studs/s): a walk blends toward the sprint between them.
	walkSpeed: number,
	runSpeed: number,
	gaits: GaitScales,
	-- Asset ids (rbxassetid://N) per surface; each step plays one at random. `default` is the fallback for an empty
	-- surface, and must not be empty.
	surfaces: SurfacePools,
}

return {}
