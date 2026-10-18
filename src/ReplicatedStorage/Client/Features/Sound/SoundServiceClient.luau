--!strict
--[=[
	SoundServiceClient: plays registered sounds on this client (design:
	docs/superpowers/specs/2026-10-09-sound-design.md).

	- `play(id, { at?, volumeScale?, pitchScale? })` — a one-shot (or looped) sound, 2D or positional, in its group,
	  with its pitch variance and concurrency cap applied. Returns a handle to stop it early (or to steer its Sound).
	- `playOneShot(id, options?)` — the same sound, fire-and-forget: no handle, so its Sound is reused. A finished
	  one-shot's Sound stays idle where it played (SoundIdlePool: a foot, a part, the 2D SoundService, a fixed point's
	  anchor) and the next one-shot there re-points it (SoundId, volume, pitch) instead of creating a Sound. Several
	  can play at one place at once (a sprint's overlapping steps never cut each other off); at most IDLE_PER_PLACE
	  stay idle per place (IDLE_SHARED for the shared places), the rest are destroyed. A place's idle voices go with
	  it (they are its children), and places that left the world are swept on later releases.
	- `playMusic(id?, fade?)` / `setAmbience(layer, id?, fade?)` — looping tracks that crossfade.
	- `setGroupVolume(group, volume)` — the per-group sliders (Music / SFX / UI / Ambient).
	- Listens for the server's `SoundEvents.Play` (one-shots).
	- A non-looped sound whose asset never loads (LOAD_TIMEOUT after its play), or whose place is removed from the game
	  without being destroyed, is released: its Ended never fires, so it would otherwise keep its Sound, its anchor and
	  its concurrency slot for good (and a watcher of its handle would never let go).

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

-- A reusable one-shot Sound, at its place (a fixed point's Sound sits in its own anchor in the Terrain).
type Voice = {
	sound: Sound,
	anchor: Attachment?,
	place: Instance,
	-- The voice token of the play it is sounding now; nil while idle.
	token: number?,
}

local log = Logger.new("SoundServiceClient")

local rng = Random.new()
local voices = SoundVoiceTracker.new()
local idle: SoundIdlePool.SoundIdlePool<Instance, Voice> = SoundIdlePool.new()
local groups: { [string]: SoundGroup? } = {}
-- token -> how to stop the sound playing for it (so an evicted voice can be stopped).
local playing: { [number]: () -> () } = {}
local music: Sound? = nil
local ambience: { [string]: Sound? } = {}
-- created: Sounds made for plays; reused: one-shots that re-pointed an idle Sound; unloaded: released unloaded.
local counters = { played = 0, evicted = 0, unknown = 0, created = 0, reused = 0, unloaded = 0 }
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

-- Fades `sound` to `volume` over `duration`, then calls `done` (immediately when duration <= 0).
local function fadeTo(sound: Sound, volume: number, duration: number, done: (() -> ())?)
	if duration <= 0 then
		sound.Volume = volume
		if done ~= nil then
			done()
		end
		return
	end
	local tween = TweenService:Create(sound, TweenInfo.new(duration), { Volume = volume })
	if done ~= nil then
		local finish = done
		tween.Completed:Once(function()
			finish()
		end)
	end
	tween:Play()
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

-- A Sound built from a registry entry, not yet parented or playing.
local function build(id: string, def: SoundTypes.SoundDef, volumeScale: number, pitchScale: number): Sound
	local sound = Instance.new("Sound")
	configure(sound, id, def, volumeScale, pitchScale)
	counters.created += 1
	return sound
end

-- Parents a sound where it should play from; returns an anchor to destroy with it (a Vector3 needs one).
local function place(sound: Sound, at: SoundTypes.PlayAt?): Instance?
	if at == nil then
		-- Outside the Workspace a Sound plays without position (2D).
		sound.Parent = SoundService
		return nil
	end
	if typeof(at) == "Vector3" then
		local anchor = Instance.new("Attachment")
		anchor.Name = `{sound.Name}Anchor`
		anchor.WorldPosition = at
		anchor.Parent = Workspace.Terrain
		sound.Parent = anchor
		return anchor
	end
	sound.Parent = at
	return nil
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

-- Destroys the idle voices of places that left the world (deparented without being destroyed).
local function sweep()
	for _, at in idle:places() do
		if at.Parent == nil then
			for _, voice in idle:forget(at) do
				destroyVoice(voice)
			end
		end
	end
end

-- Ends a one-shot voice's play: frees its slot and keeps it idle at its place (or destroys it when that is full,
-- gone, or it never loaded).
local function release(voice: Voice, keep: boolean)
	local token = voice.token
	if token == nil then
		return
	end
	voice.token = nil
	voices:finish(token)
	playing[token] = nil
	local sound = voice.sound
	sound:Stop()
	local cap = if voice.place == SoundService or voice.anchor ~= nil
		then SoundConstants.IDLE_SHARED
		else SoundConstants.IDLE_PER_PLACE
	if not keep or voice.place.Parent == nil or sound.Parent == nil or not idle:put(voice.place, voice, cap) then
		destroyVoice(voice)
	end
	releases += 1
	if releases >= SWEEP_EVERY then
		releases = 0
		sweep()
	end
end

-- A new one-shot voice at `place` (an anchor of its own for a fixed point), released when it ends.
local function newVoice(at: Instance, point: Vector3?): Voice
	local sound = Instance.new("Sound")
	counters.created += 1
	local voice: Voice = { sound = sound, anchor = nil, place = at, token = nil }
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
	-- Its place removed from the game without being destroyed: it can never end, so let it go.
	sound.AncestryChanged:Connect(function()
		if voice.token ~= nil and not sound:IsDescendantOf(game) then
			release(voice, false)
		end
	end)
	-- Destroyed with its place (a character leaving, a part being destroyed): forget it, idle or playing.
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

local function crossfade(current: Sound?, id: string?, fade: number, scale: number): Sound?
	if current ~= nil then
		local outgoing = current
		fadeTo(outgoing, 0, fade, function()
			outgoing:Destroy()
		end)
	end
	if id == nil then
		return nil
	end
	local def = SoundRegistry.get(id)
	if def == nil then
		counters.unknown += 1
		log:warn(`unknown sound "{id}"`)
		return nil
	end
	local sound = build(id, def, scale, 1)
	sound.Looped = true
	local target = sound.Volume
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	fadeTo(sound, target, fade)
	return sound
end

export type SoundServiceClient = {
	dependencies: { string },
	start: (self: SoundServiceClient) -> (),
	getState: (self: SoundServiceClient) -> { [string]: any },

	play: (self: SoundServiceClient, id: string, options: SoundTypes.PlayOptions?) -> SoundHandle?,
	playOneShot: (self: SoundServiceClient, id: string, options: SoundTypes.PlayOptions?) -> (),
	playMusic: (self: SoundServiceClient, id: string?, fade: number?) -> (),
	setAmbience: (self: SoundServiceClient, layer: string, id: string?, fade: number?) -> (),
	setGroupVolume: (self: SoundServiceClient, group: SoundGroupName, volume: number) -> (),
}

local SoundServiceClient: SoundServiceClient = {
	dependencies = {},

	--[=[
		Listens for server-requested sounds. (Volume groups are created on first use: the first `play` or
		`setGroupVolume` that names them.)
	]=]
	start = function(self)
		SoundEvents.packets.Play.listen(function(data)
			self:playOneShot(data.id, { at = data.position })
		end)
	end,

	--[=[
		Plays a registered sound. Nil (and a warning) for an unknown id.
	]=]
	play = function(_self, id, options)
		local def = SoundRegistry.get(id)
		if def == nil then
			counters.unknown += 1
			log:warn(`unknown sound "{id}"`)
			return nil
		end
		local scale = if options ~= nil and options.volumeScale ~= nil then options.volumeScale else 1
		local pitchScale = if options ~= nil and options.pitchScale ~= nil then options.pitchScale else 1
		local sound = build(id, def, scale, pitchScale)
		local anchor = place(sound, if options ~= nil then options.at else nil)

		local token = claim(id, def)
		playing[token] = function()
			sound:Destroy()
		end

		local function cleanup()
			voices:finish(token)
			playing[token] = nil
			if anchor ~= nil then
				anchor:Destroy()
			elseif sound.Parent ~= nil then
				sound:Destroy()
			end
		end
		-- Destroying (eviction, stop, or an anchor part going away) always frees the voice.
		sound.Destroying:Once(function()
			voices:finish(token)
			playing[token] = nil
		end)
		if not sound.Looped then
			sound.Ended:Once(cleanup)
			guardLoad(sound, function()
				return playing[token] ~= nil
			end, cleanup)
			-- Its place removed from the game without being destroyed: it can never end. (A loop is its caller's.)
			sound.AncestryChanged:Connect(function()
				if playing[token] ~= nil and not sound:IsDescendantOf(game) then
					cleanup()
				end
			end)
		end
		sound:Play()
		counters.played += 1

		local handle: SoundHandle = {
			sound = sound,
			stop = function(_handle, fade)
				fadeTo(sound, 0, fade or 0, cleanup)
			end,
		}
		return handle
	end,

	--[=[
		Plays a registered sound and forgets it (no handle): its Sound is reused from the idle voices at its place,
		else created and kept for reuse when it ends. A looped sound needs a handle to stop it, so it goes through
		`play`. Warns for an unknown id.
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
		local at = if options ~= nil then options.at else nil
		local point: Vector3? = nil
		local where: Instance = SoundService
		if typeof(at) == "Vector3" then
			point = at
			where = Workspace.Terrain
		elseif typeof(at) == "Instance" then
			where = at
		end
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
		end
		local scale = if options ~= nil and options.volumeScale ~= nil then options.volumeScale else 1
		local pitchScale = if options ~= nil and options.pitchScale ~= nil then options.pitchScale else 1
		local sound = current.sound
		configure(sound, id, def, scale, pitchScale)
		sound.TimePosition = 0

		local token = claim(id, def)
		current.token = token
		playing[token] = function()
			release(current, true)
		end
		sound:Play()
		counters.played += 1
		guardLoad(sound, function()
			return current.token == token
		end, function()
			release(current, false)
		end)
	end,

	--[=[
		Crossfades to a music track (looped), or to silence with nil.
	]=]
	playMusic = function(_self, id, fade)
		music = crossfade(music, id, fade or SoundConstants.DEFAULT_FADE, 1)
	end,

	--[=[
		Crossfades one named ambience layer (looped) to a sound, or to silence with nil. Layers mix.
	]=]
	setAmbience = function(_self, layer, id, fade)
		local next = crossfade(ambience[layer], id, fade or SoundConstants.DEFAULT_FADE, 1)
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
		return {
			music = if music ~= nil then music.Name else "none",
			ambience = layers,
			counters = table.clone(counters),
			idle = idle:count(),
		}
	end,
}

return SoundServiceClient
