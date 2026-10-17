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
	-- Code-built bursts (VfxBurstSystem). A Workspace attribute that, when true, puts every feature back on its
	-- pre-polish particles: the A/B switch for before/after checks and a kill switch.
	LEGACY_ATTRIBUTE = "VfxLegacy",
	-- Idle rigs kept per burst id, how far from the camera a burst still plays, and the Folder in Workspace that
	-- holds funnel hosts (client-local parts).
	POOL_CAPACITY = 4,
	DEFAULT_BURST_DISTANCE = 150,
	LOCAL_FOLDER = "VfxLocal",
	-- A funnel's spin (radians per second at full strength) and the share of change an emitter write waits for.
	FUNNEL_SPIN = 7,
	WRITE_THRESHOLD = 0.03,
	-- Graphics quality at or below which burst lights are skipped.
	LIGHT_MIN_QUALITY = 4,
	-- Cleanup Crew's palette: Gloom is dark purple-black smoke with teal edges; Gleam is warm gold; dust is a warm
	-- grey-beige; porcelain is cream with a lilac shade; paper is a warm cream.
	PALETTE = table.freeze({
		gloom = Color3.fromRGB(46, 26, 64),
		gloomMid = Color3.fromRGB(72, 40, 98),
		gloomEdge = Color3.fromRGB(70, 214, 196),
		gleam = Color3.fromRGB(255, 206, 92),
		gleamLight = Color3.fromRGB(255, 236, 168),
		gleamDeep = Color3.fromRGB(240, 160, 52),
		dust = Color3.fromRGB(196, 178, 150),
		dustDark = Color3.fromRGB(150, 134, 112),
		grime = Color3.fromRGB(74, 54, 46),
		porcelain = Color3.fromRGB(250, 246, 236),
		porcelainShade = Color3.fromRGB(206, 196, 232),
		paper = Color3.fromRGB(250, 244, 226),
		sparkle = Color3.fromRGB(226, 255, 246),
		pippa = Color3.fromRGB(178, 128, 255),
	}),
})
