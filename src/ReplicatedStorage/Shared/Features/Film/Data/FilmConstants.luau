--!strict
--[=[
	FilmConstants: the trailer filming tools' names and tuning (admin-only; the trailer plan, 2026-11-06).

	@class FilmConstants
]=]

return table.freeze({
	-- Hides every screen, label and prompt on this client (admins only), and brings them back.
	HIDE_KEY = Enum.KeyCode.F7,
	-- Turns the film camera on and off (admins only).
	CAMERA_KEY = Enum.KeyCode.F8,
	-- The film camera's mode priority: above every gameplay and UI camera mode.
	CAMERA_PRIORITY = 1000,
	-- ScreenGuis the hide leaves showing: the admin console, so the UI can always be brought back.
	KEEP_GUIS = table.freeze({ Cmdr = true }),
	-- The `filmlight` presets: added to the place's own Lighting.ExposureCompensation.
	LIGHT_PRESETS = table.freeze({ normal = 0, dark = -0.8, bright = 0.8 }),
})
