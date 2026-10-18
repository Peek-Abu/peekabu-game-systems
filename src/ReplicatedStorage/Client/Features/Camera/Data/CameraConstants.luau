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
	-- No first person in normal play. At 4 studs Pippa (her 2.4-stud head, ears to 2.9 studs above it, the backpack)
	-- takes about a quarter of the screen's width with the room still readable past her; at 3.5 her head starts to
	-- crowd the middle. Authored views (a hiding spot's peek, the catch and reveal shots) frame themselves regardless.
	MIN_ZOOM_DISTANCE = 4,
	-- The subject's fade from the final camera-to-head distance (CameraFadeSystem): opaque at FADE_FAR and beyond,
	-- hidden at FADE_NEAR and inside. FADE_FAR sits a stud under MIN_ZOOM_DISTANCE (the head rides about a stud above
	-- the camera's focus), so only a camera the walls pull in fades her; the ramp stays at or above the engine's own
	-- fade (which ends at 1.25 studs) at every distance.
	FADE_NEAR = 1,
	FADE_FAR = 3,
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
