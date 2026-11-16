--!strict
--[=[
	SoundVoicePool: the reusable voices behind every play on this client (split out of SoundServiceClient). A voice is
	a Sound kept idle where it last played (SoundIdlePool): `start` re-points an idle one at its place (or makes a new
	one), claims its id's concurrency slot (SoundVoiceTracker; the oldest is stopped at the cap) and plays it;
	`release` stops it, drops its effects, silences it and keeps it idle (or destroys it when its place is full, gone,
	or it never loaded). Places that left the world are swept every SWEEP_EVERY releases. Also keeps the looping
	positional plays (placed again by SoundServiceClient.setPlaces), the raised idle caps (prewarm), and the counters
	SoundServiceClient's getState reports.

	Spec covers placeOf, capOf and configure; the rest is a Sound/Instance shell.

	@class SoundVoicePool
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SoundShared = ReplicatedStorage.Shared.Features.Sound
local SoundTypes = require(SoundShared.Data.SoundTypes)
local SoundConstants = require(SoundShared.Data.SoundConstants)
local SoundFormulas = require(SoundShared.Utils.SoundFormulas)
local SoundGroupTracker = require(ReplicatedStorage.Client.Features.Sound.State.SoundGroupTracker)
local SoundIdlePool = require(ReplicatedStorage.Client.Features.Sound.State.SoundIdlePool)
local SoundVoiceTracker = require(ReplicatedStorage.Client.Features.Sound.State.SoundVoiceTracker)

type SoundGroupName = SoundTypes.SoundGroupName
type SoundBusName = SoundTypes.SoundBusName
type SoundPlace = SoundTypes.SoundPlace

-- A reusable Sound, at its place (a fixed point's Sound sits in its own anchor in the Terrain).
export type Voice = {
	sound: Sound,
	anchor: Attachment?,
	place: Instance,
	-- The voice token of the play it is sounding now; nil while idle.
	token: number?,
	-- A handle's fade-out running on it (cancelled when it is released).
	fade: Tween?,
}

local placeGroupFor = SoundGroupTracker.placeGroupFor
local placeFor = SoundGroupTracker.placeFor

local rng = Random.new()
local voices = SoundVoiceTracker.new()
local idle: SoundIdlePool.SoundIdlePool<Instance, Voice> = SoundIdlePool.new()
-- The idle cap of each place pre-warmed above its default (a place that left the world is forgotten by the sweep).
local caps: { [Instance]: number } = {}
-- The looping positional plays, placed again on every setPlaces: their volume group and where they play from.
local placedLoops: { [Sound]: { group: SoundGroupName, bus: SoundBusName?, at: SoundTypes.PlayAt } } = {}
-- token -> how to stop the sound playing for it (so an evicted voice can be stopped).
local playing: { [number]: () -> () } = {}
-- created: Sounds made for plays and tracks; prewarmed: idle voices made ahead of any play (prewarm); reused: plays
-- that re-pointed an idle voice; resumed: track starts that replayed a kept Sound; unloaded: released unloaded.
local counters = {
	played = 0,
	evicted = 0,
	unknown = 0,
	created = 0,
	prewarmed = 0,
	reused = 0,
	resumed = 0,
	unloaded = 0,
}
-- Releases since the last sweep of places that left the world.
local releases = 0
local SWEEP_EVERY = 64

-- Points `sound` at a registry entry: its asset, volume, a picked pitch, loop and group (its `place`'s, if any).
local function configure(
	sound: Sound,
	id: string,
	def: SoundTypes.SoundDef,
	volumeScale: number,
	pitchScale: number,
	place: SoundPlace?
)
	sound.Name = id
	if sound.SoundId ~= def.assetId then
		sound.SoundId = def.assetId
	end
	sound.Volume = def.volume * volumeScale
	sound.PlaybackSpeed = SoundFormulas.pickPitch(def.pitch, rng:NextNumber()) * pitchScale
	sound.Looped = def.looped == true
	sound.SoundGroup = placeGroupFor(def.group, def.bus, place)
	-- Max first at its widest, so the min never meets a reused voice's smaller max on the way.
	sound.RollOffMaxDistance = SoundConstants.DEFAULT_ROLL_OFF_MAX
	sound.RollOffMinDistance = def.rollOffMinDistance or SoundConstants.DEFAULT_ROLL_OFF_MIN
	sound.RollOffMaxDistance = def.rollOffMaxDistance or SoundConstants.DEFAULT_ROLL_OFF_MAX
end

-- Where a play at `at` keeps its voices, and the fixed point for a Vector3 (its anchor's position).
local function placeOf(at: SoundTypes.PlayAt?): (Instance, Vector3?)
	if typeof(at) == "Vector3" then
		return Workspace.Terrain, at
	elseif typeof(at) == "Instance" then
		return at, nil
	end
	-- Outside the Workspace a Sound plays without position (2D).
	return SoundService, nil
end

-- How many idle voices `place` keeps.
local function capOf(place: Instance): number
	local base = if place == SoundService or place == Workspace.Terrain
		then SoundConstants.IDLE_SHARED
		else SoundConstants.IDLE_PER_PLACE
	local raised = caps[place]
	return if raised ~= nil and raised > base then raised else base
end

-- Releases `sound` if it never loaded LOAD_TIMEOUT after its play (`still` says the play is still the current one).
local function guardLoad(sound: Sound, still: () -> boolean, release: () -> ())
	if sound.IsLoaded then
		return
	end
	task.delay(SoundConstants.LOAD_TIMEOUT, function()
		if still() and not sound.IsLoaded then
			counters.unloaded += 1
			release()
		end
	end)
end

local function destroyVoice(voice: Voice)
	local anchor = voice.anchor
	if anchor ~= nil then
		anchor:Destroy()
	else
		voice.sound:Destroy()
	end
end

-- Destroys the idle voices of places that left the world (deparented without being destroyed), and forgets their
-- raised caps.
local function sweep()
	for _, at in idle:places() do
		if at.Parent == nil then
			for _, voice in idle:forget(at) do
				destroyVoice(voice)
			end
		end
	end
	for at in caps do
		if at.Parent == nil then
			caps[at] = nil
		end
	end
end

-- Ends a voice's play: frees its slot and keeps it idle at its place (or destroys it when that is full, gone, or
-- `keep` is false: it never loaded, or a handle's caller may still steer it).
local function release(voice: Voice, keep: boolean)
	local token = voice.token
	if token == nil then
		return
	end
	voice.token = nil
	voices:finish(token)
	playing[token] = nil
	local fade = voice.fade
	if fade ~= nil then
		voice.fade = nil
		fade:Cancel()
	end
	local sound = voice.sound
	placedLoops[sound] = nil
	sound:Stop()
	for _, child in sound:GetChildren() do
		if child:IsA("SoundEffect") then
			child:Destroy()
		end
	end
	sound.Volume = 0
	if
		not keep
		or voice.place.Parent == nil
		or sound.Parent == nil
		or not idle:put(voice.place, voice, capOf(voice.place))
	then
		destroyVoice(voice)
	end
	releases += 1
	if releases >= SWEEP_EVERY then
		releases = 0
		sweep()
	end
end

-- A new voice at `place` (an anchor of its own for a fixed point), released when it ends. (Its caller counts it:
-- created for a play, prewarmed ahead of one.)
local function newVoice(at: Instance, point: Vector3?): Voice
	local sound = Instance.new("Sound")
	sound.Volume = 0
	local voice: Voice = { sound = sound, anchor = nil, place = at, token = nil, fade = nil }
	if point ~= nil then
		local anchor = Instance.new("Attachment")
		anchor.Name = "OneShotAnchor"
		anchor.WorldPosition = point
		anchor.Parent = Workspace.Terrain
		sound.Parent = anchor
		voice.anchor = anchor
	else
		sound.Parent = at
	end
	sound.Ended:Connect(function()
		release(voice, true)
	end)
	-- Its place removed from the game without being destroyed: a non-looped play can never end, so let it go. (A
	-- loop is its handle's: its caller stops it.)
	sound.AncestryChanged:Connect(function()
		if voice.token ~= nil and not sound.Looped and not sound:IsDescendantOf(game) then
			release(voice, false)
		end
	end)
	-- Destroyed with its place (a character leaving, a pile popping): forget it, idle or playing.
	sound.Destroying:Once(function()
		local token = voice.token
		if token ~= nil then
			voice.token = nil
			voices:finish(token)
			playing[token] = nil
		end
		idle:remove(voice.place, voice)
		placedLoops[sound] = nil
	end)
	return voice
end

-- Starts a voice slot for `id`, stopping the oldest voice when the id is at its cap.
local function claim(id: string, def: SoundTypes.SoundDef): number
	local token, evicted = voices:start(id, def.maxConcurrent)
	if evicted ~= nil then
		local stop = playing[evicted]
		if stop ~= nil then
			counters.evicted += 1
			stop()
		end
	end
	return token
end

-- Plays `id` on a voice at its place (an idle one re-pointed, else a new one). `handled`: a handle holds it, so an
-- eviction destroys it rather than keeping it for reuse.
local function start(
	id: string,
	def: SoundTypes.SoundDef,
	options: SoundTypes.PlayOptions?,
	handled: boolean
): (Voice, number)
	local at = if options ~= nil then options.at else nil
	local where, point = placeOf(at)
	local current: Voice
	local idleVoice = idle:take(where)
	if idleVoice ~= nil then
		counters.reused += 1
		local anchor = idleVoice.anchor
		if anchor ~= nil and point ~= nil then
			anchor.WorldPosition = point
		end
		current = idleVoice
	else
		current = newVoice(where, point)
		counters.created += 1
	end
	local scale = if options ~= nil and options.volumeScale ~= nil then options.volumeScale else 1
	local pitchScale = if options ~= nil and options.pitchScale ~= nil then options.pitchScale else 1
	local sound = current.sound
	configure(sound, id, def, scale, pitchScale, placeFor(def, at))
	sound.TimePosition = 0
	if at ~= nil and def.looped == true and def.heardEverywhere ~= true and def.place == nil then
		placedLoops[sound] = { group = def.group, bus = def.bus, at = at }
	end

	local token = claim(id, def)
	current.token = token
	local voice = current
	playing[token] = function()
		release(voice, not handled)
	end
	sound:Play()
	counters.played += 1
	if not sound.Looped then
		guardLoad(sound, function()
			return voice.token == token
		end, function()
			release(voice, false)
		end)
	end
	return voice, token
end

local SoundVoicePool = {
	idle = idle,
	caps = caps,
	placedLoops = placedLoops,
	counters = counters,
	configure = configure,
	placeOf = placeOf,
	capOf = capOf,
	release = release,
	newVoice = newVoice,
	start = start,
}

return SoundVoicePool
