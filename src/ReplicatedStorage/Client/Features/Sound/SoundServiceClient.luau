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
	- `setPlaces(boxes, listener, fade?)` — the place cut (docs/superpowers/specs/2026-11-04-sound-places.md): a
	  positional play is placed as it starts (SoundFormulas.placeOf its point in the outdoor `boxes`: Building or
	  Outside) and joins its place's group nested in its volume group (`SFX/Building`); only the `listener`'s place is
	  heard (SoundFormulas.placeGain), the other's group fades to 0 over `fade`. A looping positional play is placed
	  again on every call (it may move through a door). 2D plays and tracks are placeless, and `heardEverywhere` sounds
	  never placed, unless the sound is pinned (`SoundDef.place`): a pinned sound, a 2D bed or a track included, is
	  always in its place's group (the yard bed Outside, the office bed Building), so the same switch crossfades them.
	- `listener()` / `placeAt(point)` — the listener's place now, and the place of a point in the world (nil without
	  boxes), for features that choose what to play by place (the yard's sweeteners, the outdoor footstep layer).
	- Listens for the server's `SoundEvents.Play` (one-shots: the server never makes a Sound).
	- A non-looped sound whose asset never loads (LOAD_TIMEOUT after its play), or whose place is removed from the game
	  without being destroyed, is released: its Ended never fires, so it would otherwise keep its Sound, its anchor and
	  its concurrency slot for good (and a handle's watcher, like the results jingle's duck, would never let go).
	- A voice going idle stops, drops the effects put on it while it played (the dread's EQ) and goes silent (volume
	  0), so nothing scanning the playing sounds takes it for one.

	Spec-exempt shell (Sound instances, TweenService, ByteNet); the rules live in SoundRegistry,
	SoundFormulas, SoundVoiceTracker and SoundIdlePool. The SoundGroups and the place cut's state live in
	SoundGroupTracker, and the voices (start, release, the idle caps, the counters) in SoundVoicePool, both split out
	of this file.

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
local SoundGroupTracker = require(ReplicatedStorage.Client.Features.Sound.State.SoundGroupTracker)
local SoundVoicePool = require(ReplicatedStorage.Client.Features.Sound.State.SoundVoicePool)

type SoundGroupName = SoundTypes.SoundGroupName
type SoundPlace = SoundTypes.SoundPlace
type Voice = SoundVoicePool.Voice

export type SoundHandle = {
	sound: Sound,
	stop: (self: SoundHandle, fade: number?) -> (),
}

local log = Logger.new("SoundServiceClient")

local groupFor = SoundGroupTracker.groupFor
local placeGroupFor = SoundGroupTracker.placeGroupFor
local pointOf = SoundGroupTracker.pointOf
local placeFor = SoundGroupTracker.placeFor
local idle = SoundVoicePool.idle
local caps = SoundVoicePool.caps
local placedLoops = SoundVoicePool.placedLoops
local counters = SoundVoicePool.counters
local configure = SoundVoicePool.configure
local placeOf = SoundVoicePool.placeOf
local capOf = SoundVoicePool.capOf
local release = SoundVoicePool.release
local newVoice = SoundVoicePool.newVoice
local start = SoundVoicePool.start

local music: Sound? = nil
local ambience: { [string]: Sound? } = {}
-- Each looping track's kept Sound, by its slot ("music" or the ambience layer) and id, and its running fade.
local tracks: { [string]: Sound? } = {}
local trackFades: { [Sound]: Tween? } = {}

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
				configure(made, id, def, 1, 1, placeFor(def, nil))
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
				configure(sound, id, def, 1, 1, placeFor(def, nil))
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
	setPlaces: (
		self: SoundServiceClient,
		boxes: { SoundTypes.SoundPlaceBox },
		listener: SoundPlace?,
		fade: number?
	) -> (),
	listener: (self: SoundServiceClient) -> SoundPlace?,
	placeAt: (self: SoundServiceClient, point: Vector3) -> SoundPlace?,
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

	--[=[
		The place cut: `boxes` are the outdoor volumes (none = nothing is placed), `listener` the local player's place.
		A change of listener fades each place group to its gain over `fade` (0: at once, under a cover); every looping
		positional play is placed again.
	]=]
	setPlaces = function(_self, boxes, listener, fade)
		SoundGroupTracker.setPlaces(boxes, listener, fade)
		-- (A heardEverywhere or pinned loop is never in placedLoops.)
		for sound, loop in placedLoops do
			sound.SoundGroup =
				placeGroupFor(loop.group, loop.bus, SoundFormulas.placeOf(pointOf(loop.at), SoundGroupTracker.boxes()))
		end
	end,

	--[=[
		The local player's place now (setPlaces); nil while nothing is placed (the hub, a layout with no grounds).
	]=]
	listener = function(_self)
		return SoundGroupTracker.listener()
	end,

	--[=[
		The place of `point` among the outdoor boxes (SoundFormulas.placeOf); nil without boxes.
	]=]
	placeAt = function(_self, point)
		return SoundFormulas.placeOf(point, SoundGroupTracker.boxes())
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
		local loops = 0
		for _ in placedLoops do
			loops += 1
		end
		return {
			listenerPlace = SoundGroupTracker.listener() or "none",
			placedLoops = loops,
			music = if music ~= nil then music.Name else "none",
			ambience = layers,
			counters = table.clone(counters),
			idle = idle:count(),
			tracks = kept,
		}
	end,
}

return SoundServiceClient
