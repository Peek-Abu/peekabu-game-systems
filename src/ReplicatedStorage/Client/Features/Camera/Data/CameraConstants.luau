--!strict
--[=[
	CameraConstants: camera tuning values. Static data (spec-exempt); tune per game here.

	@class CameraConstants
]=]

return table.freeze({
	-- Cleanup Crew interior camera: native Zoom occlusion plus bounded orbit.
	MAX_ZOOM_DISTANCE = 16,
	MIN_ZOOM_DISTANCE = 0.5,
	-- Shake: the largest rotation offset at full trauma, in radians (pitch, yaw, roll).
	SHAKE_MAX_PITCH = math.rad(6),
	SHAKE_MAX_YAW = math.rad(6),
	SHAKE_MAX_ROLL = math.rad(4),
	-- How fast the shake noise moves (higher = more frantic).
	SHAKE_FREQUENCY = 18,
	-- Trauma lost per second (1 = a full-strength shake fades in one second).
	TRAUMA_DECAY = 1.2,
	-- Follow-mode smoothing rate when the mode does not set one.
	FOLLOW_SHARPNESS = 12,
	-- The render step the camera service runs in: just after the engine camera updates.
	RENDER_STEP_NAME = "PeekabuCamera",
	RENDER_PRIORITY_OFFSET = 1,
})
