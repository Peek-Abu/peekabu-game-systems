--!strict
--[=[
	ReplicationBodyStateSender: carries timed body states to the screens that show the body (character replication R3
	spec, "Timed body state"). The replication service owns one relay over its body and player maps; each
	kind (actions today) is defined once and gets a typed channel.

	Who receives what:
	- `set` sends the kind's Started message to the body's owner (when its client is ready) and to every
	  observer (`ReplicationObserverUtils.observersOf`). A replaced state needs no stop: the new Started replaces it.
	- `clear` (an EARLY stop) sends Stopped to the same set. A state that runs out its duration sends
	  nothing: every receiver knows the duration and the shared safety cap (`ReplicationStateTimingUtils`).
	- `replayTo` sends every live state on a body, with its original start time, to one viewer: the
	  service calls it right after that viewer's reliable `Enter`, so ordering on the one reliable channel
	  puts Enter first.
	- `clearBody` drops a body's states silently (respawn, slot switch, leave): receivers clear on the
	  slot table's epoch change or the body leaving, so no message is owed.

	Kinds supply their own send functions (typed ByteNet structs); the relay decides only WHO and WHEN.
	No services: time comes from the injected clock, packets go out through the kind's senders, and the two
	warnings (a refused state, a state ended by the safety cap) go to the Logger.

	@class ReplicationBodyStateSender
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicationServer = ServerScriptService.Features.Replication
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ReplicationBodyStateTracker = require(ReplicationServer.State.ReplicationBodyStateTracker)
local ReplicationObserverUtils = require(ReplicationServer.Utils.ReplicationObserverUtils)
local ReplicationFanoutSystem = require(ReplicationServer.Systems.ReplicationFanoutSystem)

type Body = ReplicationFanoutSystem.Body

local log = Logger.new("ReplicationBodyStateSender")

local ReplicationBodyStateSender = {}

--[=[
	A kind's packet senders. `target` receives a message about `subject`'s body in body epoch `epoch`.
]=]
export type Senders<D> = {
	started: (
		target: Player,
		subject: Player,
		epoch: number,
		key: string,
		data: D,
		startMs: number,
		durationMs: number?
	) -> (),
	stopped: (target: Player, subject: Player, epoch: number, key: string, startMs: number) -> (),
}

export type SetResult = ReplicationBodyStateTracker.SetResult | "no-body"

--[=[
	The typed handle a kind's owner keeps (AnimationServiceServer keeps the "action" channel).
]=]
export type Channel<D> = {
	kind: string,
	set: (
		self: Channel<D>,
		player: Player,
		key: string,
		data: D,
		startMs: number,
		durationMs: number?
	) -> SetResult,
	clear: (self: Channel<D>, player: Player, key: string) -> boolean,
	get: (self: Channel<D>, player: Player, key: string) -> ReplicationBodyStateTracker.Entry<D>?,
}

export type KindStats = {
	active: number,
	replayed: number,
	counters: ReplicationBodyStateTracker.Counters,
}

-- One defined kind, erased to the operations the relay runs across all kinds.
type KindOps = {
	replay: (subjectUserId: number, viewer: Player) -> number,
	clearBody: (userId: number) -> (),
	stats: () -> KindStats,
}

export type Relay = {
	bodies: { [number]: Body },
	players: { [number]: Player },
	nowMs: () -> number,
	maxStates: number,
	kinds: { [string]: KindOps },
}

function ReplicationBodyStateSender.new(
	bodies: { [number]: Body },
	players: { [number]: Player },
	nowMs: () -> number,
	maxStates: number?
): Relay
	return {
		bodies = bodies,
		players = players,
		nowMs = nowMs,
		maxStates = maxStates or ReplicationBodyStateTracker.DEFAULT_MAX_STATES,
		kinds = {},
	}
end

-- The owner (when ready) plus every observer of a live body; empty when the body is gone.
local function audience(relay: Relay, subject: Player): { Player }
	local body = relay.bodies[subject.UserId]
	if body == nil or not body.alive then
		return {}
	end
	local targets = ReplicationObserverUtils.observersOf(relay.bodies, relay.players, subject.UserId)
	if body.ready then
		table.insert(targets, subject)
	end
	return targets
end

--[=[
	Define a kind once (errors on a second definition). Returns its typed channel.
]=]
function ReplicationBodyStateSender.define<D>(relay: Relay, kind: string, senders: Senders<D>): Channel<D>
	assert(relay.kinds[kind] == nil, `[ReplicationBodyStateSender] body-state kind "{kind}" is already defined`)
	local store: ReplicationBodyStateTracker.Store<D> = ReplicationBodyStateTracker.new(
		relay.maxStates,
		function(userId: number, entry: ReplicationBodyStateTracker.Entry<D>)
			log:warn(`body state "{kind}/{entry.key}" on user {userId} reached the safety cap without a stop; cleared`)
		end
	)
	local replayed = 0

	relay.kinds[kind] = {
		replay = function(subjectUserId: number, viewer: Player): number
			local body = relay.bodies[subjectUserId]
			local subject: Player? = relay.players[subjectUserId]
			if body == nil or not body.alive or subject == nil then
				return 0
			end
			local entries = ReplicationBodyStateTracker.active(store, subjectUserId, relay.nowMs())
			for _, entry in entries do
				senders.started(
					viewer,
					subject,
					body.epoch.value,
					entry.key,
					entry.data,
					entry.startMs,
					entry.durationMs
				)
			end
			replayed += #entries
			return #entries
		end,
		clearBody = function(userId: number)
			ReplicationBodyStateTracker.clearBody(store, userId)
		end,
		stats = function(): KindStats
			return {
				active = ReplicationBodyStateTracker.size(store),
				replayed = replayed,
				counters = table.clone(store.counters),
			}
		end,
	}

	local channel: Channel<D> = {
		kind = kind,
		set = function(
			_self: Channel<D>,
			player: Player,
			key: string,
			data: D,
			startMs: number,
			durationMs: number?
		): SetResult
			local body = relay.bodies[player.UserId]
			if body == nil or not body.alive then
				return "no-body"
			end
			-- Annotated: Luau widens a singleton-union return to `string` on an unannotated local.
			local result: ReplicationBodyStateTracker.SetResult =
				ReplicationBodyStateTracker.set(store, player.UserId, key, data, startMs, durationMs, relay.nowMs())
			if result == "full" then
				log:warn(`body state "{kind}/{key}" refused for {player.Name}: {relay.maxStates} states already live`)
				return result
			end
			for _, target in audience(relay, player) do
				senders.started(target, player, body.epoch.value, key, data, startMs, durationMs)
			end
			return result
		end,
		clear = function(_self: Channel<D>, player: Player, key: string): boolean
			local entry = ReplicationBodyStateTracker.clear(store, player.UserId, key, relay.nowMs())
			if entry == nil then
				return false
			end
			local body = relay.bodies[player.UserId]
			if body ~= nil then
				for _, target in audience(relay, player) do
					senders.stopped(target, player, body.epoch.value, key, entry.startMs)
				end
			end
			return true
		end,
		get = function(_self: Channel<D>, player: Player, key: string): ReplicationBodyStateTracker.Entry<D>?
			return ReplicationBodyStateTracker.get(store, player.UserId, key, relay.nowMs())
		end,
	}
	return channel
end

--[=[
	Send every live state of every kind on `subjectUserId`'s body to `viewer`. Returns how many went.
]=]
function ReplicationBodyStateSender.replayTo(relay: Relay, subjectUserId: number, viewer: Player): number
	local sent = 0
	for _, ops in relay.kinds do
		sent += ops.replay(subjectUserId, viewer)
	end
	return sent
end

--[=[
	Drop every state of every kind on a body, silently (respawn, slot switch, leave).
]=]
function ReplicationBodyStateSender.clearBody(relay: Relay, userId: number)
	for _, ops in relay.kinds do
		ops.clearBody(userId)
	end
end

function ReplicationBodyStateSender.stats(relay: Relay): { [string]: KindStats }
	local out: { [string]: KindStats } = {}
	for kind, ops in relay.kinds do
		out[kind] = ops.stats()
	end
	return out
end

return ReplicationBodyStateSender
