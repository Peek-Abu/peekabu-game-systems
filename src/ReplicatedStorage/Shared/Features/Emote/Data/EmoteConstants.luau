--!strict
--[=[
	EmoteConstants: the emote wheel's input action and keys, and the pause between two emotes (design step 5; owner,
	25 Oct: B opens the wheel, emotes work everywhere, shifts included).

	@class EmoteConstants
]=]

return table.freeze({
	-- Hold to open the current employee's emote wheel (4 slots: CosmeticConstants.WHEEL_SLOTS).
	WHEEL_ACTION = "emoteWheel",
	WHEEL_KEY = Enum.KeyCode.B,
	WHEEL_GAMEPAD = Enum.KeyCode.ButtonL1,
	-- Seconds between two emotes from one player (the server's rate limit).
	COOLDOWN = 1.5,
	-- How hard the keys or stick must push (the Humanoid's MoveDirection length, 0-1) to stop the emote.
	STOP_INPUT = 0.1,
	-- A prop clip's KeyframeMarkers and keyframe names (EmotePropRegistry, EmotePropSystem): its props show at the
	-- first and hide at the second. A clip may leave out the stow (a showcase loop keeps them out).
	PROPS_SHOW = "PropsShow",
	PROPS_STOW = "PropsStow",
	-- A clip marker swapping one hand prop (its Value is the prop name), e.g. the coil out of sight and the lasso loop in.
	PROP_SHOW = "PropShow",
	PROP_HIDE = "PropHide",
	-- Under ReplicatedStorage: an emote's own prop templates, by prop name (a part on a Motor6D whose `Hand` attribute
	-- names the hand, at the template's size, like an outfit's props). A client mounts one when the skin lacks it.
	PROP_TEMPLATES_PATH = { "Assets", "CleanupCrew", "EmoteProps" },
})
