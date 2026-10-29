--!strict
--[=[
	EmoteEffectSystem: runs an emote's effects on this client from the clip's own markers (EmoteEffectRegistry), for
	every character it watches: the owner's emote replicates, so every client hears the same markers.
	- An effect starts on its `on` marker (with the marker's Value) and ends on its `off` marker. A second start of a
	  running effect ends the first copy (a new face replaces the old).
	- Safe end: the clip stopping (finish, cancel, a server stop on knockdown or hiding), a newer effect clip taking
	  over, or the release (character gone, service stopped) ends every running effect. An effect whose start errors
	  (a part missing) is skipped; the rest carry on.
	Effects are cosmetic and per client. `deps.start` does the work (EmoteVfxSystem); it returns how to end it.
	Markers only fire forward, so a client that meets a clip mid-way starts the effects from the next marker on.

	@class EmoteEffectSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local EmoteEffectRegistry = require(ReplicatedStorage.Shared.Features.Emote.Data.EmoteEffectRegistry)
local EmotePropSystem = require(ReplicatedStorage.Client.Features.Emote.Systems.EmotePropSystem)

type PropTrack = EmotePropSystem.PropTrack
type TrackSource = EmotePropSystem.TrackSource

export type Deps = {
	sourceOf: (character: Model) -> TrackSource?,
	keyForAsset: (assetId: string) -> string?,
	entryFor: (key: string) -> EmoteEffectRegistry.Entry?,
	-- Starts effect `id` on `character`; returns how to end it (nil when there is nothing to end).
	start: (id: string, character: Model, value: string) -> (() -> ())?,
}

export type EmoteEffectState = {
	tracked: number,
	running: number,
}

export type EmoteEffectSystem = {
	track: (character: Model) -> () -> (),
	getState: () -> EmoteEffectState,
}

local EmoteEffectSystem = {}

local log = Logger.new("EmoteEffectSystem")

--[=[
	A system. `deps` must give `start`; the rest default to the live Animator and the registry.
]=]
function EmoteEffectSystem.new(deps: Deps): EmoteEffectSystem
	local tracked = 0
	local running = 0

	return {
		track = function(character)
			tracked += 1
			local released = false
			local owner: PropTrack? = nil
			local ownerCleanups: { () -> () } = {}
			local enders: { [string]: () -> () } = {}
			local cleanups: { () -> () } = {}

			local function finish(id: string)
				local ender = enders[id]
				if ender == nil then
					return
				end
				enders[id] = nil
				running -= 1
				xpcall(ender, function(err: unknown)
					log:warn(`ending {id}: {err}`)
				end)
			end

			local function begin(id: string, value: string)
				finish(id)
				local ok, result = pcall(deps.start, id, character, value)
				if not ok then
					log:warn(`starting {id}: {result}`)
					return
				end
				if result ~= nil then
					enders[id] = result
					running += 1
				end
			end

			local function disown()
				for _, cleanup in ownerCleanups do
					cleanup()
				end
				table.clear(ownerCleanups)
				owner = nil
				local ids = {}
				for id in enders do
					table.insert(ids, id)
				end
				for _, id in ids do
					finish(id)
				end
			end

			local function adopt(track: PropTrack)
				local key = deps.keyForAsset(track.assetId)
				local entry = if key ~= nil then deps.entryFor(key) else nil
				if entry == nil or released then
					return
				end
				disown()
				owner = track
				for _, effect in entry.effects do
					table.insert(
						ownerCleanups,
						track.onMarker(effect.on, function(value)
							if owner == track then
								begin(effect.id, value)
							end
						end)
					)
					local off = effect.off
					if off ~= nil then
						table.insert(
							ownerCleanups,
							track.onMarker(off, function()
								if owner == track then
									finish(effect.id)
								end
							end)
						)
					end
				end
				table.insert(
					ownerCleanups,
					track.onStopped(function()
						if owner == track then
							disown()
						end
					end)
				)
			end

			local function bind(source: TrackSource)
				table.insert(cleanups, source.onPlayed(adopt))
				for _, track in source.playing() do
					adopt(track)
				end
			end

			local source = deps.sourceOf(character)
			if source ~= nil then
				bind(source)
			else
				-- A replicated character can arrive before its Animator does.
				local waiting: RBXScriptConnection? = nil
				waiting = character.DescendantAdded:Connect(function()
					local found = deps.sourceOf(character)
					if found ~= nil and not released then
						local connection = waiting
						if connection ~= nil then
							connection:Disconnect()
						end
						bind(found)
					end
				end)
				table.insert(cleanups, function()
					local connection = waiting
					if connection ~= nil then
						connection:Disconnect()
					end
				end)
			end

			return function()
				if released then
					return
				end
				released = true
				tracked -= 1
				disown()
				for _, cleanup in cleanups do
					cleanup()
				end
				table.clear(cleanups)
			end
		end,

		getState = function()
			return { tracked = tracked, running = running }
		end,
	}
end

--[=[
	The live defaults for `deps` (the Animator, the registry) around a `start`.
]=]
function EmoteEffectSystem.live(start: (id: string, character: Model, value: string) -> (() -> ())?): EmoteEffectSystem
	return EmoteEffectSystem.new({
		sourceOf = EmotePropSystem.realSource,
		keyForAsset = EmoteEffectRegistry.keyForAsset,
		entryFor = EmoteEffectRegistry.get,
		start = start,
	})
end

return EmoteEffectSystem
