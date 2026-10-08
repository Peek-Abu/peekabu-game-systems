--!strict
--[=[
	ReplicationActionTracker: what this client knows about server-granted actions on the bodies it shows, and what it
	plays on their rigs (character replication R3 spec, "Body state receiver"). One path for the owner's own
	rig and for every puppet: both receive the same `ActionStarted` / `ActionStopped` messages.

	- A body holds at most one action per layer; a new Started on a layer replaces the old one.
	- An action plays only when its body has a rig (`attach`) that is live (not LOD-frozen) AND the body's
	  clock has reached the action's start: until then it is pending. The clock is per body (injected): the
	  owner plays at the session clock; a puppet at its render time, so the clip lines up with the motion
	  the viewer is drawing (the same moment its placement comes from).
	- It starts `(clock − startMs) × speed` seconds into the clip, so a viewer that walks into range
	  mid-action (the server's replay after `Enter`) joins at the right point. No continuous re-sync.
	- An action past its duration is ignored on arrival and dropped when its time is up (a one-shot clip
	  ends by itself; an open-ended one is stopped at the shared safety cap).
	- Messages from another body epoch than the one the slot table (or the owner's Spawn) announced are
	  stale and ignored.

	Readouts for F4: counters, the worst start-alignment drift, and a length check (a clip whose real length
	disagrees with its declared `durationMs` is counted and reported once per clip).

	Pure: the registry lookup, the clocks and the rigs' players are injected.

	@class ReplicationActionTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationPlayerSystem = require(ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerSystem)
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)
local ReplicationStateTimingUtils =
	require(ReplicatedStorage.Shared.Features.Replication.Utils.ReplicationStateTimingUtils)

type AnimationDef = AnimationTypes.AnimationDef

local ReplicationActionTracker = {}

-- A real clip within this many ms of its declared length passes the length check.
ReplicationActionTracker.LENGTH_TOLERANCE_MS = 50
-- A start more than this far into the clip counts as joining late (the replay-on-enter case).
ReplicationActionTracker.LATE_JOIN_MS = 250

-- The `ActionStarted` payload (ReplicationEvents).
export type Started = {
	userId: number,
	epoch: number,
	layer: number,
	wireId: number,
	variant: number,
	speedMilli: number,
	startMs: number,
	durationMs: number?,
}

-- The `ActionStopped` payload.
export type Stopped = {
	userId: number,
	epoch: number,
	layer: number,
	startMs: number,
}

--[=[
	The slice of AnimationPlayerSystem this module drives (structural, so specs fake two functions).
]=]
export type Target = {
	play: (
		self: Target,
		id: string,
		opts: AnimationPlayerSystem.PlayOpts?
	) -> (AnimationPlayerSystem.PlayHandle?, string?),
	stop: (self: Target, id: string, fadeTime: number?) -> boolean,
}

export type Outcome = "played" | "pending" | "expired" | "stale" | "unknown" | "failed"

export type Counters = {
	started: number,
	stopped: number,
	played: number,
	joinedLate: number,
	pendingRig: number,
	expired: number,
	stale: number,
	unknown: number,
	loadFailures: number,
	lengthMismatches: number,
	capped: number,
	maxDriftMs: number,
}

type Action = {
	id: string,
	def: AnimationDef,
	variant: number,
	speed: number,
	startMs: number,
	durationMs: number?,
	handle: AnimationPlayerSystem.PlayHandle?,
}

type Body = {
	epoch: number?,
	target: Target?,
	live: boolean,
	actions: { [number]: Action }, -- by layer index
}

export type State = {
	resolveWire: (wireId: number) -> (string?, AnimationDef?),
	clock: (userId: number) -> number,
	bodies: { [number]: Body },
	checkedClips: { [string]: boolean },
	warnings: { string }, -- length-check reports, drained by the shell into the log
	counters: Counters,
}

function ReplicationActionTracker.new(
	resolveWire: (wireId: number) -> (string?, AnimationDef?),
	clock: (userId: number) -> number
): State
	return {
		resolveWire = resolveWire,
		clock = clock,
		bodies = {},
		checkedClips = {},
		warnings = {},
		counters = {
			started = 0,
			stopped = 0,
			played = 0,
			joinedLate = 0,
			pendingRig = 0,
			expired = 0,
			stale = 0,
			unknown = 0,
			loadFailures = 0,
			lengthMismatches = 0,
			capped = 0,
			maxDriftMs = 0,
		},
	}
end

local function isFinite(value: number): boolean
	return value == value and math.abs(value) ~= math.huge
end

local function bodyOf(state: State, userId: number): Body
	local body = state.bodies[userId]
	if body == nil then
		body = { epoch = nil, target = nil, live = false, actions = {} }
		state.bodies[userId] = body
	end
	return body
end

local function stopAction(body: Body, action: Action)
	local target = body.target
	if target ~= nil and action.handle ~= nil then
		target:stop(action.id)
	end
	action.handle = nil
end

local function dropAll(body: Body)
	for layer, action in body.actions do
		stopAction(body, action)
		body.actions[layer] = nil
	end
end

-- Clip seconds since the action started, at its speed (never negative).
local function clipTime(action: Action, nowMs: number): number
	return math.max(nowMs - action.startMs, 0) / 1000 * action.speed
end

-- Plays an action on its body's rig if the rig is live and the body's clock has reached the start.
local function tryPlay(state: State, userId: number, body: Body, layer: number, action: Action): Outcome
	local target = body.target
	local nowMs = state.clock(userId)
	if target == nil or not body.live or nowMs < action.startMs then
		return "pending"
	end
	local startAt = clipTime(action, nowMs)
	if not isFinite(startAt) then
		body.actions[layer] = nil -- a non-finite clock or start must never reach the player
		state.counters.unknown += 1
		return "failed"
	end
	local handle, reason = target:play(action.id, { variant = action.variant, speed = action.speed, startAt = startAt })
	if handle == nil then
		body.actions[layer] = nil
		if reason == "elapsed" then
			state.counters.expired += 1
			return "expired"
		end
		if reason == "load-failed" then
			state.counters.loadFailures += 1
		end
		return "failed"
	end
	action.handle = handle
	state.counters.played += 1
	if startAt * 1000 / action.speed > ReplicationActionTracker.LATE_JOIN_MS then
		state.counters.joinedLate += 1
	end
	return "played"
end

--[=[
	An `ActionStarted` arrived. Returns what happened to it.
]=]
function ReplicationActionTracker.started(state: State, message: Started): Outcome
	local body = bodyOf(state, message.userId)
	if body.epoch ~= nil and body.epoch ~= message.epoch then
		state.counters.stale += 1
		return "stale"
	end
	local id, def = state.resolveWire(message.wireId)
	local layer = AnimationTypes.layerAt(message.layer)
	local durationMs = message.durationMs
	if
		not isFinite(message.startMs)
		or not isFinite(message.speedMilli)
		or (durationMs ~= nil and not isFinite(durationMs))
	then
		state.counters.unknown += 1
		return "unknown"
	end
	if id == nil or def == nil or layer == nil or def.layer ~= layer or message.speedMilli <= 0 then
		state.counters.unknown += 1
		return "unknown"
	end
	if ReplicationStateTimingUtils.isOver(message.startMs, message.durationMs, state.clock(message.userId)) then
		state.counters.expired += 1
		return "expired"
	end
	local current = body.actions[message.layer]
	if current ~= nil then
		stopAction(body, current)
	end
	local action: Action = {
		id = id,
		def = def,
		variant = message.variant,
		speed = message.speedMilli / 1000,
		startMs = message.startMs,
		durationMs = message.durationMs,
		handle = nil,
	}
	body.actions[message.layer] = action
	state.counters.started += 1
	if body.target == nil then
		state.counters.pendingRig += 1
	end
	return tryPlay(state, message.userId, body, message.layer, action)
end

--[=[
	An `ActionStopped` arrived: stops the action it names (same layer and start), if still held.
]=]
function ReplicationActionTracker.stopped(state: State, message: Stopped): boolean
	local body = state.bodies[message.userId]
	if body == nil or body.epoch ~= message.epoch then
		return false
	end
	local action = body.actions[message.layer]
	if action == nil or action.startMs ~= message.startMs then
		return false
	end
	stopAction(body, action)
	body.actions[message.layer] = nil
	state.counters.stopped += 1
	return true
end

--[=[
	The body's epoch, from the slot table (a puppet) or a Spawn (the owner). Another epoch's actions are dropped.
]=]
function ReplicationActionTracker.resetBody(state: State, userId: number, epoch: number)
	local body = bodyOf(state, userId)
	if body.epoch ~= epoch then
		dropAll(body)
		body.epoch = epoch
	end
end

--[=[
	A rig now shows this body (a puppet acquired, the owner rig built): pending actions start.
]=]
function ReplicationActionTracker.attach(state: State, userId: number, epoch: number, target: Target)
	ReplicationActionTracker.resetBody(state, userId, epoch)
	local body = bodyOf(state, userId)
	body.target = target
	body.live = true
	for layer, action in body.actions do
		tryPlay(state, userId, body, layer, action)
	end
end

-- Epochs are uint8 and wrap (`(value + 1) % 256`): `epoch` is older than `current` when it trails it by
-- 1..127 steps modulo 256.
local function isOlderEpoch(epoch: number, current: number): boolean
	local behind = (current - epoch) % 256
	return behind >= 1 and behind <= 127
end

--[=[
	The owner's rig is built. The owner's own slot row is the epoch authority, so a build of an OLDER epoch
	(a Spawn still building when the next slot row arrived) is dropped instead of rewinding the body; a
	newer or equal epoch attaches. Returns whether it attached.
]=]
function ReplicationActionTracker.attachOwner(state: State, userId: number, epoch: number, target: Target): boolean
	local current = bodyOf(state, userId).epoch
	if current ~= nil and isOlderEpoch(epoch, current) then
		return false
	end
	ReplicationActionTracker.attach(state, userId, epoch, target)
	return true
end

--[=[
	The rig is gone (the shell already stopped its tracks): actions stay, pending a new rig.
]=]
function ReplicationActionTracker.detach(state: State, userId: number)
	local body = state.bodies[userId]
	if body == nil then
		return
	end
	body.target = nil
	body.live = false
	for _, action in body.actions do
		action.handle = nil
	end
end

--[=[
	LOD freeze (false) and unfreeze (true). Unfreezing re-plays every action still running at its current
	point (the shell held the tracks while frozen) and drops the ones that ended meanwhile.
]=]
function ReplicationActionTracker.setLive(state: State, userId: number, live: boolean)
	local body = state.bodies[userId]
	if body == nil or body.live == live or body.target == nil then
		return
	end
	body.live = live
	if not live then
		return
	end
	local nowMs = state.clock(userId)
	for layer, action in body.actions do
		if ReplicationStateTimingUtils.isOver(action.startMs, action.durationMs, nowMs) then
			stopAction(body, action)
			body.actions[layer] = nil
		else
			tryPlay(state, userId, body, layer, action)
		end
	end
end

--[=[
	The body left this viewer's range: its actions go (the server replays them on the next Enter); the
	epoch stays (the slot table still knows the body).
]=]
function ReplicationActionTracker.forget(state: State, userId: number)
	local body = state.bodies[userId]
	if body ~= nil then
		dropAll(body)
		body.target = nil
		body.live = false
	end
end

--[=[
	The body is gone from the slot table (released): forget everything about it.
]=]
function ReplicationActionTracker.remove(state: State, userId: number)
	local body = state.bodies[userId]
	if body ~= nil then
		dropAll(body)
		state.bodies[userId] = nil
	end
end

local function checkLength(state: State, action: Action)
	local durationMs = action.def.durationMs
	local handle = action.handle
	if durationMs == nil or handle == nil then
		return
	end
	local clipKey = `{action.id}#{action.variant}`
	if state.checkedClips[clipKey] then
		return
	end
	local length = handle:length()
	if length <= 0 then
		return -- not loaded yet; checked on a later step
	end
	state.checkedClips[clipKey] = true
	local realMs = math.floor(length * 1000 + 0.5)
	if math.abs(realMs - durationMs) > ReplicationActionTracker.LENGTH_TOLERANCE_MS then
		state.counters.lengthMismatches += 1
		table.insert(
			state.warnings,
			`"{action.id}" variant {action.variant} is {realMs} ms long but declares durationMs = {durationMs}`
		)
	end
end

--[=[
	Once per frame: starts pending actions whose time has come, drops actions whose time is up (stopping an
	open-ended one at the safety cap), and runs the length check on newly loaded clips.
]=]
function ReplicationActionTracker.step(state: State)
	for userId, body in state.bodies do
		local nowMs = state.clock(userId)
		for layer, action in body.actions do
			if ReplicationStateTimingUtils.isOver(action.startMs, action.durationMs, nowMs) then
				if action.durationMs == nil then
					stopAction(body, action)
					state.counters.capped += 1
				elseif not body.live then
					stopAction(body, action) -- a held (frozen) clip must not resume past its end
				end
				body.actions[layer] = nil
			elseif action.handle == nil then
				tryPlay(state, userId, body, layer, action)
			else
				checkLength(state, action)
			end
		end
	end
end

--[=[
	Readout only (no re-seek, spec decision 9): the worst gap, in clip ms, between where each live action's
	track is and where its start time says it should be. Updates `counters.maxDriftMs`; returns this
	sample's worst.
]=]
function ReplicationActionTracker.sampleDrift(state: State): number
	local worst = 0
	for userId, body in state.bodies do
		if not body.live then
			continue
		end
		local nowMs = state.clock(userId)
		for _, action in body.actions do
			local handle = action.handle
			if handle == nil or not handle:isPlaying() then
				continue
			end
			local length = handle:length()
			local expected = clipTime(action, nowMs)
			if length > 0 then
				if action.def.looped then
					expected %= length
				elseif expected >= length then
					continue
				end
			end
			local drift = math.abs(handle:timePosition() - expected)
			if length > 0 and action.def.looped then
				drift = math.min(drift, length - drift) -- across the loop seam
			end
			worst = math.max(worst, drift * 1000)
		end
	end
	state.counters.maxDriftMs = math.max(state.counters.maxDriftMs, math.floor(worst + 0.5))
	return worst
end

--[=[
	How many actions are held and how many are playing on a rig (F4).
]=]
function ReplicationActionTracker.counts(state: State): (number, number)
	local held, playing = 0, 0
	for _, body in state.bodies do
		for _, action in body.actions do
			held += 1
			if action.handle ~= nil then
				playing += 1
			end
		end
	end
	return held, playing
end

return ReplicationActionTracker
