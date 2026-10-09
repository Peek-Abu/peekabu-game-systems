--!strict
--[=[
	VfxTypes: the types the Vfx feature shares. Types only (spec-exempt).
	Design: docs/superpowers/specs/2026-10-09-vfx-design.md.

	@class VfxTypes
]=]

export type Recipe = {
	-- The Folder name under ReplicatedStorage.Assets.Vfx whose children are cloned at the spot.
	template: string,
	-- Seconds a non-burst emitter or light stays on.
	lifetime: number,
	-- A SoundRegistry id played at the spot.
	sound: string?,
	-- Camera trauma (0..1) at the effect's centre, falling off to 0 at `shakeRadius`.
	trauma: number?,
	shakeRadius: number?,
}

-- One system's screen-effect request. Absent fields request nothing.
export type ScreenRequest = {
	blur: number?, -- BlurEffect.Size
	brightness: number?, -- ColorCorrection offsets (summed across requests)
	contrast: number?,
	saturation: number?,
	tint: Color3?, -- multiplied across requests
	depthOfField: number?, -- DepthOfFieldEffect.FarIntensity (0..1)
}

-- The combined, fully-specified screen state the effects are eased toward.
export type ScreenState = {
	blur: number,
	brightness: number,
	contrast: number,
	saturation: number,
	tint: Color3,
	depthOfField: number,
}

-- An atmosphere preset: only the Lighting values it changes.
export type Atmosphere = {
	clockTime: number?,
	brightness: number?,
	exposure: number?,
	ambient: Color3?,
	outdoorAmbient: Color3?,
	fogColor: Color3?,
	fogStart: number?,
	fogEnd: number?,
}

-- Every Lighting value the atmosphere system manages, fully specified.
export type AtmosphereValues = {
	clockTime: number,
	brightness: number,
	exposure: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	fogColor: Color3,
	fogStart: number,
	fogEnd: number,
}

return {}
