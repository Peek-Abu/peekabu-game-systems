--!strict
--[=[
	CameraConstants: camera tuning values. Static data (spec-exempt); tune per game here.

	@class CameraConstants
]=]

return table.freeze({
	-- Cleanup Crew interior camera: native Zoom occlusion plus our own pass (CameraOcclusionSystem), and a bounded
	-- orbit. 13 studs sits the camera over Pippa's shoulder in the office's 12-stud-high rooms instead of hard against
	-- the far wall; 16 had it pinned to walls (and popping in and out) in most rooms.
	MAX_ZOOM_DISTANCE = 13,
	MIN_ZOOM_DISTANCE = 0.5,
	-- The occlusion pass: the sphere swept from the focus to the camera (studs). Larger than the near plane's corner
	-- (about 0.15 at 70 degrees), so the near plane never reaches a surface, and the corkboards, dado rails and door
	-- trims a few tenths proud of a wall stay in front of the camera.
	OCCLUSION_RADIUS = 0.4,
	-- How many see-through parts one sweep looks past before it stops at the last one.
	OCCLUSION_MAX_PIERCE = 8,
	-- How fast the camera eases back out once the view clears (1/s, exponential); it always snaps in.
	OCCLUSION_RELEASE = 6,
	-- Closer than this to its focus the camera is first person: the pass leaves it alone (studs).
	OCCLUSION_MIN_DISTANCE = 1,
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
