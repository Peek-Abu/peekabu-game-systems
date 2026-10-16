--!strict
--[=[
	AnimationCarryClipHarness: the carry validator's (AnimationCarryHarness) clips. `show` plays a carrier's idle or
	walk frozen at a sampled frame once the clip has loaded, and `shown` confirms the engine shows that frame at full
	weight, so a frame that cannot be shown fails the entry instead of judging frame 0 or the rest pose.

	@class AnimationCarryClipHarness
]=]
local RunService = game:GetService("RunService")

local AnimationCarryClipHarness = {}

-- How long a clip may take to load before its frame is reported unshown.
local CLIP_LOAD_TIMEOUT = 10
-- How far the shown frame may sit from the sampled one (seconds, and track weight).
local SHOWN_TIME_TOLERANCE = 1 / 60
local SHOWN_WEIGHT_TOLERANCE = 0.01

--[=[
	Plays the clip `id` on `animatorOf` frozen at `at` (a fraction of its length), once the clip has loaded: a
	track's Length is 0 until its asset arrives, and a TimePosition set before that is lost, so the first sample of
	a clip not yet loaded in this session would show its frame 0, or the rest pose, instead of the frame asked for.
	Nil and the reason when the clip does not load within `timeout` seconds (default CLIP_LOAD_TIMEOUT).
]=]
function AnimationCarryClipHarness.show(
	animatorOf: Animator,
	id: string,
	at: number,
	timeout: number?
): (AnimationTrack?, string?)
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animatorOf:LoadAnimation(animation)
	local deadline = os.clock() + (timeout or CLIP_LOAD_TIMEOUT)
	while track.Length <= 0 and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	if track.Length <= 0 then
		track:Destroy()
		return nil, `clip {id} did not load within {timeout or CLIP_LOAD_TIMEOUT} s`
	end
	track:Play(0)
	track:AdjustSpeed(0)
	track.TimePosition = track.Length * at
	return track, nil
end

--[=[
	Nil when `track` shows the frame at `at` of its length at full weight; otherwise what it shows instead.
]=]
function AnimationCarryClipHarness.shown(track: AnimationTrack, at: number): string?
	local wanted = track.Length * at
	if
		not track.IsPlaying
		or math.abs(track.TimePosition - wanted) > SHOWN_TIME_TOLERANCE
		or math.abs(track.WeightCurrent - 1) > SHOWN_WEIGHT_TOLERANCE
	then
		return string.format(
			"clip shows %.3f s at weight %.2f, not %.3f s at full weight",
			track.TimePosition,
			track.WeightCurrent,
			wanted
		)
	end
	return nil
end

return AnimationCarryClipHarness
