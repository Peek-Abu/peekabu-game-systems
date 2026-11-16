--!strict
--[=[
	EmotePropAnimatorUtils: a character's Animator seen as the prop and effect systems read it. `realSource` wraps
	the Animator (under the Humanoid or AnimationController, nil until it exists) as a TrackSource: its playing tracks
	and each track it starts later, every AnimationTrack wrapped as a PropTrack (its asset id in the registry's
	`canonical` form, time, keyframe times, markers and stop). Nothing here keeps state; each watch hands back its
	release. Split out of EmotePropSystem.

	@class EmotePropAnimatorUtils
]=]

-- What the system reads of a playing AnimationTrack.
export type PropTrack = {
	assetId: string,
	timePosition: () -> number,
	isPlaying: () -> boolean,
	-- The time of the keyframe with this name, or nil when the clip has none.
	timeOfKeyframe: (name: string) -> number?,
	-- The callback gets the marker's Value (e.g. a face name).
	onMarker: (name: string, callback: (value: string) -> ()) -> () -> (),
	onStopped: (callback: () -> ()) -> () -> (),
}

-- A character's Animator: the tracks playing now, and each one it starts later.
export type TrackSource = {
	playing: () -> { PropTrack },
	onPlayed: (callback: (track: PropTrack) -> ()) -> () -> (),
}

local EmotePropAnimatorUtils = {}

-- The registry's canonical `rbxassetid://N` form of an AnimationId (a replicated track may carry another form).
local function canonical(id: string): string
	local digits = string.match(id, "(%d+)$")
	return if digits ~= nil then "rbxassetid://" .. digits else id
end
EmotePropAnimatorUtils.canonical = canonical

local function wrapTrack(track: AnimationTrack): PropTrack
	return {
		assetId = canonical(track.Animation.AnimationId),
		timePosition = function()
			return track.TimePosition
		end,
		isPlaying = function()
			return track.IsPlaying
		end,
		timeOfKeyframe = function(name)
			-- Errors when the clip has no keyframe of that name.
			local ok, time = pcall(function()
				return track:GetTimeOfKeyframe(name)
			end)
			return if ok then time else nil
		end,
		onMarker = function(name, callback)
			local connection = track:GetMarkerReachedSignal(name):Connect(function(value: string?)
				callback(value or "")
			end)
			return function()
				connection:Disconnect()
			end
		end,
		onStopped = function(callback)
			local connection = track.Stopped:Connect(callback)
			return function()
				connection:Disconnect()
			end
		end,
	}
end

local function animatorSource(animator: Animator): TrackSource
	return {
		playing = function()
			local out = {}
			for _, track in animator:GetPlayingAnimationTracks() do
				table.insert(out, wrapTrack(track))
			end
			return out
		end,
		onPlayed = function(callback)
			local connection = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
				callback(wrapTrack(track))
			end)
			return function()
				connection:Disconnect()
			end
		end,
	}
end

-- The character's Animator, under its Humanoid or AnimationController (nil until it exists).
function EmotePropAnimatorUtils.realSource(character: Model): TrackSource?
	local host: Instance? = character:FindFirstChildOfClass("Humanoid")
	if host == nil then
		host = character:FindFirstChildOfClass("AnimationController")
	end
	local animator = if host ~= nil then host:FindFirstChildOfClass("Animator") else nil
	return if animator ~= nil then animatorSource(animator) else nil
end

return EmotePropAnimatorUtils
