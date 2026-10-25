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
})
