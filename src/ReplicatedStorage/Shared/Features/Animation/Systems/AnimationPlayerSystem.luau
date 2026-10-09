--!strict
--[=[
	AnimationPlayerSystem: the pure core of track ownership (Phase 6 spec, Decisions 2 + 4). One player
	per animator; the ONLY code path through which animations load and play.

	The old game hand-rolled `Instance.new("Animation")` + `LoadAnimation` at 81 call sites, usually
	per PLAY (every slide re-loaded its animation). Here: load once per (animator, assetId), cache
	the track, replay from the cache, and clean up when the animator goes away.

	This module never touches an Instance. It speaks to the world through an injected
	`AnimatorSeam` (implemented over a real Animator by `AnimationPlayerEngineSystem`) and resolves ids
	through an injected registry lookup — so the cache, bookkeeping, and stop-class rules are
	unit-tested with fakes. The same seam trick as `CustomizationWearRules`.

	Because the player records what IT is playing, bulk-stop verbs match on each entry's DECLARED
	interruption class (Decision 4) — no `GetPlayingAnimationTracks()`, no name parsing.

	@class AnimationPlayerSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

type AnimationDef = AnimationTypes.AnimationDef
type InterruptionClass = AnimationTypes.InterruptionClass

--[=[
	A loaded track as the seam exposes it. Thin verbs over `AnimationTrack`; disconnectors are
	returned by the subscription functions.
	@interface SeamTrack
]=]
export type SeamTrack = {
	play: (fadeTime: number, weight: number, speed: number) -> (),
	stop: (fadeTime: number) -> (),
	adjustSpeed: (speed: number) -> (),
	setPriority: (priority: Enum.AnimationPriority) -> (),
	setLooped: (looped: boolean) -> (),
	isPlaying: () -> boolean,
	onEnded: (callback: () -> ()) -> () -> (),
	onMarker: (markerName: string, callback: (param: string?) -> ()) -> () -> (),
	setTimePosition: (seconds: number) -> (),
	timePosition: () -> number,
	-- The clip length in seconds; 0 until the engine has loaded the asset.
	length: () -> number,
}

--[=[
	What the player needs from an animator: load an asset into a track, and say when the animator
	is gone so the player can clean up after itself.
	@interface AnimatorSeam
]=]
export type AnimatorSeam = {
	load: (assetId: string) -> SeamTrack?,
	onRemoved: (callback: () -> ()) -> () -> (),
}

--[=[
	Per-play options, layered over the registry entry's declared defaults.
	@interface PlayOpts
]=]
export type PlayOpts = {
	fadeTime: number?,
	speed: number?,
	weight: number?,
	priority: Enum.AnimationPriority?,
	-- Which asset: 0 = the entry's own assetId, k = variants[k]. Nil rolls (local-only plays); a
	-- replicated action always passes the server's choice so every screen plays the same clip.
	variant: number?,
	-- Seconds into the clip (clip time, i.e. TimePosition) to start from: a viewer joining an action
	-- mid-way. Wrapped for a looped entry; a one-shot already past its end is refused ("elapsed").
	startAt: number?,
}

--[=[
	What a consumer holds instead of a raw `AnimationTrack`.
	@interface PlayHandle
]=]
export type PlayHandle = {
	id: string,
	assetId: string,
	stop: (self: PlayHandle, fadeTime: number?) -> (),
	adjustSpeed: (self: PlayHandle, speed: number) -> (),
	isPlaying: (self: PlayHandle) -> boolean,
	onMarker: (self: PlayHandle, markerName: string, callback: (param: string?) -> ()) -> () -> (),
	timePosition: (self: PlayHandle) -> number,
	length: (self: PlayHandle) -> number,
}

--[=[
	One row of `playing()` — what the Debugger panel renders.
	@interface PlayingInfo
]=]
export type PlayingInfo = {
	id: string,
	assetId: string,
	interruption: InterruptionClass,
	looped: boolean,
	priority: Enum.AnimationPriority,
	weight: number,
	speed: number,
}

export type StopClassResult = {
	stopped: { string },
	refused: boolean,
}

export type Counters = {
	loads: number,
	hits: number,
}

export type AnimationPlayerSystem = {
	play: (self: AnimationPlayerSystem, id: string, opts: PlayOpts?) -> (PlayHandle?, string?),
	warm: (self: AnimationPlayerSystem, id: string) -> (boolean, string?),
	stop: (self: AnimationPlayerSystem, id: string, fadeTime: number?) -> boolean,
	stopClass: (self: AnimationPlayerSystem, class: InterruptionClass, fadeTime: number?) -> StopClassResult,
	stopAll: (self: AnimationPlayerSystem, fadeTime: number?) -> (),
	setPaused: (self: AnimationPlayerSystem, paused: boolean) -> (),
	isPaused: (self: AnimationPlayerSystem) -> boolean,
	playing: (self: AnimationPlayerSystem) -> { PlayingInfo },
	counters: (self: AnimationPlayerSystem) -> Counters,
	destroy: (self: AnimationPlayerSystem) -> (),
}

type LiveEntry = {
	def: AnimationDef,
	track: SeamTrack,
	assetId: string,
	-- What we last TOLD the track (the engine exposes no reliable getters for these, and what we
	-- requested is what the panel needs to show anyway).
	priority: Enum.AnimationPriority,
	weight: number,
	speed: number,
	disconnectEnded: () -> (),
}

local DEFAULT_FADE = 0.1

-- Where a clip `startAt` seconds in really is: wrapped for a loop, nil for a one-shot already over. A track
-- whose asset has not loaded yet reports length 0; it is seeked as asked (the engine clamps).
local function resolveStart(track: SeamTrack, startAt: number, looped: boolean): number?
	local length = track.length()
	if startAt <= 0 or length <= 0 then
		return math.max(startAt, 0)
	end
	if looped then
		return startAt % length
	end
	if startAt >= length then
		return nil
	end
	return startAt
end

local AnimationPlayerModule = {}

--[=[
	Builds a player over an animator seam.
	@param seam AnimatorSeam
	@param resolve (id: string) -> AnimationDef? -- normally `AnimationRegistry.get`
	@param roll ((count: number) -> number)? -- variant picker, 1..count; defaults to math.random
	@return AnimationPlayerSystem
]=]
function AnimationPlayerModule.new(
	seam: AnimatorSeam,
	resolve: (id: string) -> AnimationDef?,
	roll: ((count: number) -> number)?
): AnimationPlayerSystem
	local pickIndex: (count: number) -> number = roll or function(count: number)
		return math.random(1, count)
	end

	local cache: { [string]: SeamTrack } = {}
	local live: { [string]: LiveEntry } = {}
	local counters: Counters = { loads = 0, hits = 0 }
	local destroyed = false
	-- A level-of-detail freeze (e.g. a distant NPC): every live track held at speed 0; each entry keeps its
	-- requested speed.
	local paused = false
	local disconnectRemoved: (() -> ())? = nil

	local function dropLive(id: string)
		local entry = live[id]
		if entry ~= nil then
			entry.disconnectEnded()
			live[id] = nil
		end
	end

	local function stopEntry(id: string, fadeTime: number?)
		local entry = live[id]
		if entry ~= nil then
			-- Drop bookkeeping FIRST: the track's ended callback fires from stop, and it must not
			-- find a live row to double-remove.
			dropLive(id)
			entry.track.stop(fadeTime or DEFAULT_FADE)
		end
	end

	local function stopAllTracks(fadeTime: number?)
		local ids: { string } = {}
		for id in live do
			table.insert(ids, id)
		end
		for _, id in ids do
			stopEntry(id, fadeTime)
		end
	end

	local function makeHandle(id: string, entry: LiveEntry): PlayHandle
		-- A handle addresses THE PLAY IT CAME FROM, not the id. Once that play is superseded (a
		-- replay, a variant reroll) or stopped, the handle goes inert — otherwise a stale handle
		-- could stop a newer replay or retune a track the bookkeeping no longer describes, which
		-- desyncs the panel from what is actually playing (Qodo PR #13).
		local function isCurrent(): boolean
			return live[id] == entry
		end
		return {
			id = id,
			assetId = entry.assetId,
			stop = function(_self: PlayHandle, fadeTime: number?)
				if not isCurrent() then
					return
				end
				stopEntry(id, fadeTime)
			end,
			adjustSpeed = function(_self: PlayHandle, speed: number)
				if not isCurrent() then
					return
				end
				entry.speed = speed
				if not paused then
					entry.track.adjustSpeed(speed)
				end
			end,
			isPlaying = function(_self: PlayHandle): boolean
				return isCurrent() and entry.track.isPlaying()
			end,
			onMarker = function(_self: PlayHandle, markerName: string, callback: (param: string?) -> ()): () -> ()
				if not isCurrent() then
					return function() end
				end
				return entry.track.onMarker(markerName, callback)
			end,
			timePosition = function(_self: PlayHandle): number
				return if isCurrent() then entry.track.timePosition() else 0
			end,
			length = function(_self: PlayHandle): number
				return entry.track.length()
			end,
		}
	end

	local player: AnimationPlayerSystem = {
		play = function(_self: AnimationPlayerSystem, id: string, opts: PlayOpts?): (PlayHandle?, string?)
			if destroyed then
				return nil, "destroyed"
			end
			local def = resolve(id)
			if def == nil then
				return nil, "unknown-id"
			end

			-- The asset: the requested variant, or a roll over the entry's own id plus its variants.
			local assetId = def.assetId
			local variants = def.variants
			local requested = if opts ~= nil then opts.variant else nil
			if requested ~= nil then
				local count = if variants ~= nil then #variants else 0
				if requested ~= math.floor(requested) or requested < 0 or requested > count then
					return nil, "bad-variant"
				end
				if requested > 0 and variants ~= nil then
					assetId = variants[requested]
				end
			elseif variants ~= nil and #variants > 0 then
				local index = pickIndex(#variants + 1)
				if index > 1 then
					assetId = variants[index - 1]
				end
			end
			local startAt = if opts ~= nil then opts.startAt else nil

			local existing = live[id]
			if existing ~= nil and existing.assetId == assetId and def.looped and existing.track.isPlaying() then
				-- Re-playing a looped track that is already playing is a no-op: re-Play would
				-- restart the loop and thrash the fade (the pose-flap failure V3 watches for). A
				-- requested start point re-seeks it instead (an action resuming after a freeze).
				if startAt ~= nil then
					local seekTo = resolveStart(existing.track, startAt, true)
					if seekTo ~= nil then
						existing.track.setTimePosition(seekTo)
					end
				end
				return makeHandle(id, existing), nil
			end

			-- Cache per (registry id, asset): two entries aliasing the same asset get INDEPENDENT
			-- tracks, so declared priority/looped and stop verbs never cross-talk (Qodo PR #13).
			local cacheKey = `{id}\0{assetId}`
			local track = cache[cacheKey]
			if track ~= nil then
				counters.hits += 1
			else
				local loaded = seam.load(assetId)
				if loaded == nil then
					return nil, "load-failed"
				end
				counters.loads += 1
				cache[cacheKey] = loaded
				track = loaded
			end

			local start: number? = nil
			if startAt ~= nil then
				start = resolveStart(track, startAt, def.looped)
				if start == nil then
					return nil, "elapsed"
				end
			end

			local priority = if opts ~= nil and opts.priority ~= nil then opts.priority else def.priority
			track.setPriority(priority)
			track.setLooped(def.looped)

			-- Replacing a live entry whose track DIFFERS (a variant roll landed elsewhere) must
			-- stop the outgoing track, or it plays on as a ghost no stop verb can reach (Qodo
			-- PR #13). Same-track replays just refresh bookkeeping; the Play below restarts it.
			local outgoing = live[id]
			if outgoing ~= nil and outgoing.track ~= track then
				stopEntry(id, if opts ~= nil and opts.fadeTime ~= nil then opts.fadeTime else DEFAULT_FADE)
			else
				dropLive(id)
			end
			local entry: LiveEntry
			entry = {
				def = def,
				track = track,
				assetId = assetId,
				priority = priority,
				weight = if opts ~= nil and opts.weight ~= nil then opts.weight else 1,
				speed = if opts ~= nil and opts.speed ~= nil then opts.speed else 1,
				disconnectEnded = track.onEnded(function()
					-- Natural end (or a stop we did not route): leave the cache, clear the row.
					if live[id] == entry then
						dropLive(id)
					end
				end),
			}
			live[id] = entry

			local fadeTime = if opts ~= nil and opts.fadeTime ~= nil then opts.fadeTime else DEFAULT_FADE
			track.play(fadeTime, entry.weight, if paused then 0 else entry.speed)
			if start ~= nil and start > 0 then
				track.setTimePosition(start)
			end

			return makeHandle(id, entry), nil
		end,

		-- Loads an entry's track(s) into the cache without playing — the first-play-hitch killer
		-- (V3 finding). Variant sets warm every variant, since any of them may roll first.
		warm = function(_self: AnimationPlayerSystem, id: string): (boolean, string?)
			if destroyed then
				return false, "destroyed"
			end
			local def = resolve(id)
			if def == nil then
				return false, "unknown-id"
			end
			local assets = { def.assetId }
			local variants = def.variants
			if variants ~= nil then
				for _, variantId in variants do
					table.insert(assets, variantId)
				end
			end
			for _, assetId in assets do
				local cacheKey = `{id}\0{assetId}`
				if cache[cacheKey] == nil then
					local loaded = seam.load(assetId)
					if loaded == nil then
						return false, "load-failed"
					end
					counters.loads += 1
					cache[cacheKey] = loaded
				end
			end
			return true, nil
		end,

		stop = function(_self: AnimationPlayerSystem, id: string, fadeTime: number?): boolean
			if live[id] == nil then
				return false
			end
			stopEntry(id, fadeTime)
			return true
		end,

		stopClass = function(
			_self: AnimationPlayerSystem,
			class: InterruptionClass,
			fadeTime: number?
		): StopClassResult
			-- Bulk stops act on `attack` only: `protected` is protected BY DEFINITION, and
			-- `ambient` (locomotion) dying to a combat verb is the old bug class this replaces.
			-- Individual `stop(id)` still works on anything.
			if class ~= "attack" then
				return { stopped = {}, refused = true }
			end
			local stopped: { string } = {}
			for id, entry in live do
				if entry.def.interruption == class then
					table.insert(stopped, id)
				end
			end
			table.sort(stopped)
			for _, id in stopped do
				stopEntry(id, fadeTime)
			end
			return { stopped = stopped, refused = false }
		end,

		stopAll = function(_self: AnimationPlayerSystem, fadeTime: number?)
			stopAllTracks(fadeTime)
		end,

		-- Holds every live track at speed 0 (the pose stays where it is), or resumes each at its own
		-- requested speed. A play while paused starts held. Used for a level-of-detail freeze.
		setPaused = function(_self: AnimationPlayerSystem, nextPaused: boolean)
			if destroyed or paused == nextPaused then
				return
			end
			paused = nextPaused
			for _, entry in live do
				entry.track.adjustSpeed(if paused then 0 else entry.speed)
			end
		end,

		isPaused = function(_self: AnimationPlayerSystem): boolean
			return paused
		end,

		playing = function(_self: AnimationPlayerSystem): { PlayingInfo }
			local snapshot: { PlayingInfo } = {}
			for id, entry in live do
				table.insert(snapshot, {
					id = id,
					assetId = entry.assetId,
					interruption = entry.def.interruption,
					looped = entry.def.looped,
					priority = entry.priority,
					weight = entry.weight,
					speed = entry.speed,
				})
			end
			table.sort(snapshot, function(a, b)
				return a.id < b.id
			end)
			return snapshot
		end,

		counters = function(_self: AnimationPlayerSystem): Counters
			return { loads = counters.loads, hits = counters.hits }
		end,

		destroy = function(_self: AnimationPlayerSystem)
			if destroyed then
				return
			end
			stopAllTracks(0)
			destroyed = true
			table.clear(cache)
			if disconnectRemoved ~= nil then
				disconnectRemoved()
				disconnectRemoved = nil
			end
		end,
	}

	disconnectRemoved = seam.onRemoved(function()
		player:destroy()
	end)

	return player
end

return AnimationPlayerModule
