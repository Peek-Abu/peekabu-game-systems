--!strict
--[=[
	CrouchConstants: crouching (Cleanup Crew, 2026-10-17: "let's add crouch, ensure to quiet and slow footsteps to match
	animation"). Every number is a tuning hypothesis. Static data (spec-exempt).

	The crouch is the sneak: CROUCH_SPEED is 56 % of the walk (16), so it never outruns anything; it is quiet (no sprint
	noise, quieter footsteps: the Footstep feature's crouch gait) and slows the Manager's peripheral notice
	(OccupantConstants.GLANCE_CROUCH), both from the character's CROUCHING_ATTRIBUTE.

	@class CrouchConstants
]=]

return table.freeze({
	-- The Input actions: the held key (Left Ctrl; C is Hide's) and the toggle (gamepad B; the phone's CROUCH button
	-- toggles through CrouchServiceClient:toggle).
	ACTION = "crouch",
	KEYBOARD_KEY = Enum.KeyCode.LeftControl,
	TOGGLE_ACTION = "crouchToggle",
	GAMEPAD_KEY = Enum.KeyCode.ButtonB,
	CROUCH_SPEED = 9,
	-- Replicated on the character while it crouches (true, else unset): the one contract Animation (the crouch poses),
	-- Footstep (the crouch gait), Occupant (the slower glance) and the camera read.
	CROUCHING_ATTRIBUTE = "Crouching",
	-- The local camera drops this many studs while crouched (Humanoid.CameraOffset), easing in CAMERA_EASE seconds
	-- (the time to cover ~63 % of the way). Measured 2026-10-17: Pippa's head drops 0.34 studs crouched (her short legs
	-- fold little); the camera goes a touch further so the change reads. 1.1 put the eye below her own head.
	CAMERA_DROP = 0.4,
	CAMERA_EASE = 0.08,
	-- A toggle the server has not honoured within TOGGLE_CONFIRM seconds (asked while sprinting, hidden, hands full)
	-- is let go, so it never crouches the player later by surprise.
	TOGGLE_CONFIRM = 0.5,
	-- How often the server steps everyone's crouch.
	TICK = 0.05,
	-- Crouch requests are rate limited (a held key sends two, a toggle one).
	REQUEST_RATE = table.freeze({ maxRequests = 20, windowSeconds = 5 }),
})
