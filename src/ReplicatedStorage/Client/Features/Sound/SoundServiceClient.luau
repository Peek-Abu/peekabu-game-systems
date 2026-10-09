--!strict
--[=[
	SoundServiceClient: plays registered sounds on this client (design:
	docs/superpowers/specs/2026-10-09-sound-design.md).

	- `play(id, { at?, volumeScale? })` — a one-shot (or looped) sound, 2D or positional, in its group,
	  with its pitch variance and concurrency cap applied. Returns a handle to stop it early.
	- `playMusic(id?, fade?)` / `setAmbience(layer, id?, fade?)` — looping tracks that crossfade.
	- `setGroupVolume(group, volume)` — the per-group sliders (Music / SFX / UI / Ambient).
	- Listens for the server's `SoundEvents.Play`.

	Spec-exempt shell (Sound instances, TweenService, ByteNet); the rules live in SoundRegistry,
	SoundFormulas and SoundVoiceTracker.

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
local SoundVoiceTracker = require(ReplicatedStorage.Client.Features.Sound.State.SoundVoiceTracker)

type SoundGroupName = SoundTypes.SoundGroupName

export type SoundHandle = {
	sound: Sound,
	stop: (self: SoundHandle, fade: number?) -> (),
}

local log = Logger.new("SoundServiceClient")

local rng = Random.new()
local voices = SoundVoiceTracker.new()
local groups: { [string]: SoundGroup? } = {}
-- token -> the Sound playing for it (so an evicted voice can be stopped).
local playing: { [number]: Sound? } = {}
local music: Sound? = nil
local ambience: { [string]: Sound? } = {}
local counters = { played = 0, evicted = 0, unknown = 0 }

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

-- A Sound built from a registry entry, not yet parented or playing.
local function build(id: string, def: SoundTypes.SoundDef, volumeScale: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = id
	sound.SoundId = def.assetId
	sound.Volume = def.volume * volumeScale
	sound.PlaybackSpeed = SoundFormulas.pickPitch(def.pitch, rng:NextNumber())
	sound.Looped = def.looped == true
	sound.SoundGroup = groupFor(def.group)
	local rollOff = def.rollOffMaxDistance
	if rollOff ~= nil then
		sound.RollOffMaxDistance = rollOff
	end
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
	local sound = build(id, def, scale)
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
			self:play(data.id, { at = data.position })
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
		local sound = build(id, def, scale)
		local anchor = place(sound, if options ~= nil then options.at else nil)

		local token, evicted = voices:start(id, def.maxConcurrent)
		if evicted ~= nil then
			local old = playing[evicted]
			if old ~= nil then
				counters.evicted += 1
				old:Destroy()
			end
		end
		playing[token] = sound

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
		}
	end,
}

return SoundServiceClient
