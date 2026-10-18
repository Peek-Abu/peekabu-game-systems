--!strict
--[=[
	SoundServiceClient: plays registered sounds on this client (design:
	docs/superpowers/specs/2026-10-09-sound-design.md). No play creates a Sound once its place is warm: every Sound is
	a reusable voice kept idle where it last played (SoundIdlePool), and the loops are kept per track.

	- `playOneShot(id, options?)` — a sound, fire-and-forget: no handle. Its voice comes from the idle voices at its
	  place (a foot, a head, the 2D SoundService, the Terrain's fixed-point anchors), re-pointed (SoundId, volume,
	  pitch), and goes back there when it ends. Several can play at one place at once (a sprint's overlapping steps
	  never cut each other off); at most IDLE_PER_PLACE stay idle per place (IDLE_SHARED for the shared places, or what
	  the place was pre-warmed for), the rest are destroyed. A place's idle voices go with it (they are its children),
	  and places that left the world are swept on later releases.
	- `play(id, { at?, volumeScale?, pitchScale? })` — the same, with a handle to stop it (fade) or steer its Sound
	  while it plays: a loop (a typist, the whine, the chase stems) or a sound cut short. Its voice comes from the same
	  idle voices and goes back on `stop` or when it plays out; one evicted by its id's concurrency cap is destroyed (its
	  caller may still steer it). A handle's `stop` after its sound has ended does nothing.
	- `prewarm(at?, count)` — makes idle voices at a place ahead of its first plays (a character's feet on spawn, the
	  office's emitters when it is built, the Manager's head; nil = 2D, a Vector3 = the fixed-point anchors) and keeps
	  that many idle there, so steady play there never creates a Sound.
	- `playMusic(id?, fade?)` / `setAmbience(layer, id?, fade?)` — looping tracks that crossfade. Each track's Sound is
	  made once per slot and kept: a fade-out stops it, the next start plays it again.
	- `setGroupVolume(group, volume)` — the per-group sliders (Music / SFX / UI / Ambient).
	- Listens for the server's `SoundEvents.Play` (one-shots: the server never makes a Sound).
	- A non-looped sound whose asset never loads (LOAD_TIMEOUT after its play), or whose place is removed from the game
	  without being destroyed, is released: its Ended never fires, so it would otherwise keep its Sound, its anchor and
	  its concurrency slot for good (and a handle's watcher, like the results jingle's duck, would never let go).
	- A voice going idle stops, drops the effects put on it while it played (the dread's EQ) and goes silent (volume
	  0), so nothing scanning the playing sounds takes it for one.

	Spec-exempt shell (Sound instances, TweenService, ByteNet); the rules live in SoundRegistry,
	SoundFormulas, SoundVoiceTracker and SoundIdlePool.

	@class SoundServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundShared = ReplicatedStorage.Shared.Features.Sound
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SoundTypes = require(SoundShared.Data.SoundTypes)
local SoundConstants = require(SoundShared.Data.SoundConstants)
local SoundRegistry = require(SoundShared.Data.SoundRegistry)
local SoundFormulas = require(SoundShared.Utils.SoundFormulas)
local SoundEvents = require(SoundShared.Net.SoundEvents)
local SoundIdlePool = require(ReplicatedStorage.Client.Features.Sound.State.SoundIdlePool)
local SoundVoiceTracker = require(ReplicatedStorage.Client.Features.Sound.State.SoundVoiceTracker)

type SoundGroupName = SoundTypes.SoundGroupName

export type SoundHandle = {
	sound: Sound,
	stop: (self: SoundHandle, fade: number?) -> (),
}

-- A reusable Sound, at its place (a fixed point's Sound sits in its own anchor in the Terrain).
type Voice = {
	sound: Sound,
	anchor: Attachment?,
	place: Instance,
	-- The voice token of the play it is sounding now; nil while idle.
	token: number?,
	-- A handle's fade-out running on it (cancelled when it is released).
	fade: Tween?,
}

local log = Logger.new("SoundServiceClient")

local rng = Random.new()
local voices = SoundVoiceTracker.new()
local idle: SoundIdlePool.SoundIdlePool<Instance, Voice> = SoundIdlePool.new()
-- The idle cap of each place pre-warmed above its default (a place that left the world is forgotten by the sweep).
local caps: { [Instance]: number } = {}
local groups: { [string]: SoundGroup? } = {}
-- token -> how to stop the sound playing for it (so an evicted voice can be stopped).
local playing: { [number]: () -> () } = {}
local music: Sound? = nil
local ambience: { [string]: Sound? } = {}
-- Each looping track's kept Sound, by its slot ("music" or the ambience layer) and id, and its running fade.
local tracks: { [string]: Sound? } = {}
local trackFades: { [Sound]: Tween? } = {}
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

local function groupFor(name: SoundGroupName): SoundGroup
	local existing = groups[name]
	if existing ~= nil then
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = name
	created.Volume = SoundConstants.DEFAULT_GROUP_VOLUMES[name]
	created.Parent = SoundService
	groups[name] = created
	return created
end

-- Fades `sound` to `volume` over `duration`, then calls `done` (immediately when duration <= 0; never for a fade
-- that is cancelled). Returns the running tween, if any.
local function fadeTo(sound: Sound, volume: number, duration: number, done: (() -> ())?): Tween?
	if duration <= 0 then
		sound.Volume = volume
		if done ~= nil then
			done()
		end
		return nil
	end
	local tween = TweenService:Create(sound, TweenInfo.new(duration), { Volume = volume })
	if done ~= nil then
		local finish = done
		tween.Completed:Once(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed then
				finish()
			end
		end)
	end
	tween:Play()
	return tween
end

-- Points `sound` at a registry entry: its asset, volume, a picked pitch, loop and group.
local function configure(sound: Sound, id: string, def: SoundTypes.SoundDef, volumeScale: number, pitchScale: number)
	sound.Name = id
	if sound.SoundId ~= def.assetId then
		sound.SoundId = def.assetId
	end
	sound.Volume = def.volume * volumeScale
	sound.PlaybackSpeed = SoundFormulas.pickPitch(def.pitch, rng:NextNumber()) * pitchScale
	sound.Looped = def.looped == true
	sound.SoundGroup = groupFor(def.group)
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
	local where, point = placeOf(if options ~= nil then options.at else nil)
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
	configure(sound, id, def, scale, pitchScale)
	sound.TimePosition = 0

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

-- Cancels a track's running fade.
local function stopTrackFade(sound: Sound)
	local running = trackFades[sound]
	if running ~= nil then
		trackFades[sound] = nil
		running:Cancel()
	end
end

-- Fades a track's Sound to `volume`, then calls `done` (unless a later fade replaces this one).
local function fadeTrack(sound: Sound, volume: number, duration: number, done: (() -> ())?)
	stopTrackFade(sound)
	local tween = fadeTo(sound, volume, duration, done)
	if tween ~= nil then
		trackFades[sound] = tween
	end
end

-- Crossfades the `slot`'s track from `current` to `id` (nil: to silence). The track's Sound is the slot's kept one
-- for that id (made the first time): a stopped one plays from its start, one still fading out fades back up.
local function crossfade(current: Sound?, slot: string, id: string?, fade: number): Sound?
	local nextSound: Sound? = nil
	if id ~= nil then
		local def = SoundRegistry.get(id)
		if def == nil then
			counters.unknown += 1
			log:warn(`unknown sound "{id}"`)
		else
			local key = `{slot}|{id}`
			local kept = tracks[key]
			local sound: Sound
			if kept == nil then
				local made = Instance.new("Sound")
				configure(made, id, def, 1, 1)
				made.Looped = true
				made.Volume = 0
				made.Parent = SoundService
				tracks[key] = made
				counters.created += 1
				sound = made
			else
				sound = kept
				if kept ~= current then
					counters.resumed += 1
				end
			end
			if sound ~= current then
				-- Still sounding (fading out): it fades back up from where it is, without restarting.
				local sounding = sound.IsPlaying
				local from = sound.Volume
				configure(sound, id, def, 1, 1)
				sound.Looped = true
				if sounding then
					sound.Volume = from
				else
					sound.Volume = 0
					sound.TimePosition = 0
					sound:Play()
				end
			end
			fadeTrack(sound, def.volume, fade)
			nextSound = sound
		end
	end
	if current ~= nil and current ~= nextSound then
		local outgoing = current
		fadeTrack(outgoing, 0, fade, function()
			trackFades[outgoing] = nil
			outgoing:Stop()
		end)
	end
	return nextSound
end

export type SoundServiceClient = {
	dependencies: { string },
	start: (self: SoundServiceClient) -> (),
	getState: (self: SoundServiceClient) -> { [string]: any },

	play: (self: SoundServiceClient, id: string, options: SoundTypes.PlayOptions?) -> SoundHandle?,
	playOneShot: (self: SoundServiceClient, id: string, options: SoundTypes.PlayOptions?) -> (),
	prewarm: (self: SoundServiceClient, at: SoundTypes.PlayAt?, count: number) -> number,
	playMusic: (self: SoundServiceClient, id: string?, fade: number?) -> (),
	setAmbience: (self: SoundServiceClient, layer: string, id: string?, fade: number?) -> (),
	setGroupVolume: (self: SoundServiceClient, group: SoundGroupName, volume: number) -> (),
}

local SoundServiceClient: SoundServiceClient = {
	dependencies = {},

	--[=[
		Listens for server-requested sounds and warms the shared places (2D and the fixed-point anchors), so the
		shift's UI, music stings and scattered one-shots never create a Sound. (Volume groups are created on first
		use: the first `play` or `setGroupVolume` that names them.)
	]=]
	start = function(self)
		SoundEvents.packets.Play.listen(function(data)
			self:playOneShot(data.id, { at = data.position })
		end)
		self:prewarm(nil, SoundConstants.PREWARM_2D)
		self:prewarm(Vector3.zero, SoundConstants.PREWARM_POINTS)
	end,

	--[=[
		Plays a registered sound with a handle (to stop it, or steer its Sound while it plays). Nil (and a warning)
		for an unknown id.
	]=]
	play = function(_self, id, options)
		local def = SoundRegistry.get(id)
		if def == nil then
			counters.unknown += 1
			log:warn(`unknown sound "{id}"`)
			return nil
		end
		local voice, token = start(id, def, options, true)
		local sound = voice.sound
		local handle: SoundHandle = {
			sound = sound,
			stop = function(_handle, fade)
				if voice.token ~= token then
					return
				end
				local running = voice.fade
				if running ~= nil then
					voice.fade = nil
					running:Cancel()
				end
				voice.fade = fadeTo(sound, 0, fade or 0, function()
					if voice.token == token then
						release(voice, true)
					end
				end)
			end,
		}
		return handle
	end,

	--[=[
		Plays a registered sound and forgets it (no handle): its voice goes back to its place's idle voices when it
		ends. A looped sound needs a handle to stop it, so it goes through `play`. Warns for an unknown id.
	]=]
	playOneShot = function(self, id, options)
		local def = SoundRegistry.get(id)
		if def == nil then
			counters.unknown += 1
			log:warn(`unknown sound "{id}"`)
			return
		end
		if def.looped == true then
			self:play(id, options)
			return
		end
		start(id, def, options, false)
	end,

	--[=[
		Makes idle voices at `at` (an instance; nil = 2D; a Vector3 = the fixed-point anchors) until it holds `count`,
		and keeps at least that many idle there from now on, so the first plays there reuse them instead of creating
		Sounds mid-play; a play beyond them still creates one. Returns how many it made (none for a place outside the
		game).
	]=]
	prewarm = function(_self, at, count)
		local where, point = placeOf(at)
		if not where:IsDescendantOf(game) then
			return 0
		end
		if where ~= SoundService and where ~= Workspace.Terrain then
			local raised = caps[where]
			if raised == nil or raised < count then
				caps[where] = count
			end
		end
		local made = idle:prewarm(where, math.min(count, capOf(where)), function(): Voice
			return newVoice(where, point)
		end)
		counters.prewarmed += made
		return made
	end,

	--[=[
		Crossfades to a music track (looped), or to silence with nil.
	]=]
	playMusic = function(_self, id, fade)
		music = crossfade(music, "music", id, fade or SoundConstants.DEFAULT_FADE)
	end,

	--[=[
		Crossfades one named ambience layer (looped) to a sound, or to silence with nil. Layers mix.
	]=]
	setAmbience = function(_self, layer, id, fade)
		local next = crossfade(ambience[layer], `ambience:{layer}`, id, fade or SoundConstants.DEFAULT_FADE)
		if next ~= nil then
			ambience[layer] = next
		else
			ambience[layer] = nil
		end
	end,

	setGroupVolume = function(_self, group, volume)
		groupFor(group).Volume = math.clamp(volume, 0, 10)
	end,

	getState = function(_self)
		local layers: { string } = {}
		for layer in ambience do
			table.insert(layers, layer)
		end
		table.sort(layers)
		local kept = 0
		for _ in tracks do
			kept += 1
		end
		return {
			music = if music ~= nil then music.Name else "none",
			ambience = layers,
			counters = table.clone(counters),
			idle = idle:count(),
			tracks = kept,
		}
	end,
}

return SoundServiceClient
