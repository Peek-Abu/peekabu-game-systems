--!strict
--[=[
	FootstepTypes: the types the Footstep feature shares. Types only (spec-exempt).

	@class FootstepTypes
]=]

-- The outdoor surfaces (yard design Y2): each adds a shared layer under the character's own step.
export type LayerSurface = "asphalt" | "grass" | "gravel" | "puddle"

-- What a step lands on (FootstepSurfaceUtils.surfaceFor). `default` is every floor not named here.
export type Surface = "default" | "carpet" | "tile" | "wood" | "concrete" | LayerSurface

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

-- One list of strings per outdoor surface (asset ids in FootstepAssets.LAYERS, sound names in
-- FootstepAssets.LAYER_SOUND_IDS).
export type LayerPools = {
	asphalt: { string },
	grass: { string },
	gravel: { string },
	puddle: { string },
}

-- A set's proximity gate (FootstepProximityFormulas): silent while the listener is farther than `silentBeyond` studs,
-- then suddenly loud and quick (x loudVolume, x quickPitch) from there in. Bramble's steps (owner 11-13).
export type Proximity = {
	silentBeyond: number,
	loudVolume: number,
	quickPitch: number,
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
	-- Optional: silent far from the listener, suddenly loud and quick close (nil: heard at every distance).
	proximity: Proximity?,
	-- Asset ids (rbxassetid://N) per surface; each step plays one at random. `default` is the fallback for an empty
	-- surface, and must not be empty.
	surfaces: SurfacePools,
}

-- One character's body sounds (FootstepAssets.BODY_SETS): SoundRegistry names of its land and its jump variants.
export type BodySet = {
	land: string,
	jumps: { string },
}

return {}
