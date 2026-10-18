--!strict
--[=[
	ToastConstants: defaults and limits. Static data (spec-exempt).

	@class ToastConstants
]=]

return table.freeze({
	DEFAULT_STYLE = "info",
	-- Seconds on screen: default, and the range a request is clamped to.
	DEFAULT_DURATION = 4,
	MIN_DURATION = 1,
	MAX_DURATION = 15,
	-- Characters; longer text is cut.
	MAX_TEXT = 140,
	-- Toasts shown at once; a new one pushes the oldest out.
	MAX_VISIBLE = 4,
})
