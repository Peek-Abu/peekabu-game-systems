--!strict
--[=[
	VfxConstants: VFX tuning and asset locations. Static data (spec-exempt).

	@class VfxConstants
]=]

return table.freeze({
	-- Templates live at ReplicatedStorage.<ASSETS_FOLDER>.<TEMPLATE_FOLDER>.<recipe.template>.
	ASSETS_FOLDER = "Assets",
	TEMPLATE_FOLDER = "Vfx",
	-- The ParticleEmitter attribute that makes it burst this many particles instead of streaming.
	EMIT_COUNT_ATTRIBUTE = "EmitCount",
	-- How far a server-requested recipe reaches when the caller gives no radius.
	DEFAULT_SERVER_RADIUS = 200,
	-- The blur a UI scene gets when it asks for `blur`.
	UI_BLUR_SIZE = 16,
	-- How quickly screen effects ease toward their target (per second; higher = snappier).
	SCREEN_SHARPNESS = 8,
	-- Default atmosphere blend, in seconds.
	DEFAULT_ATMOSPHERE_FADE = 2,
})
