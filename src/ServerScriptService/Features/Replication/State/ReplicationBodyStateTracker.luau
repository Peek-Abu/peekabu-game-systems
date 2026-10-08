--!strict
--[=[
	ReplicationBodyStateTracker: the server's table of timed body states for ONE kind (character replication R3 spec,
	"Timed body state"). A kind (actions today; later e.g. lasting VFX statuses) owns one store; within it
	each body holds at most one state per key (for actions, the key is the animation layer).

	Rules:
	- `set` on a key the body already holds REPLACES that state; a new key is refused once the body holds
	  `maxStates` live states (the per-body safety cap, `MAX_BODY_STATES`).
	- Ended states are cleared LAZILY, whenever the body is touched (no per-state timers). A state with a
	  duration ends at `startMs + durationMs` and is counted `expired`; an open-ended one ends at the shared
	  safety cap (`ReplicationStateTimingUtils.MAX_OPEN_STATE_MS`), is counted `capped`, and reported to `onCapped` so
	  the shell can warn about a grant somebody forgot to stop.
	- `active` is the replay list for a viewer the body just entered: every live state, oldest first.
	- `clearBody` drops everything (death, respawn, slot switch, leave): receivers clear on their own, so
	  no message is owed.

	Pure: time is passed in (session ms); the data is opaque to the store.

	@class ReplicationBodyStateTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicationStateTimingUtils =
	require(ReplicatedStorage.Shared.Features.Replication.Utils.ReplicationStateTimingUtils)

local ReplicationBodyStateTracker = {}

-- MAX_BODY_STATES: live states one body may hold per kind (3 action layers today, room for growth).
ReplicationBodyStateTracker.DEFAULT_MAX_STATES = 8

export type Entry<D> = {
	key: string,
	data: D,
	startMs: number,
	durationMs: number?,
}

export type SetResult = "created" | "replaced" | "full"

export type Counters = {
	created: number,
	replaced: number,
	cleared: number,
	expired: number,
	capped: number,
	refused: number,
}

export type Store<D> = {
	maxStates: number,
	onCapped: ((userId: number, entry: Entry<D>) -> ())?,
	bodies: { [number]: { [string]: Entry<D> } },
	counters: Counters,
}

function ReplicationBodyStateTracker.new<D>(
	maxStates: number?,
	onCapped: ((userId: number, entry: Entry<D>) -> ())?
): Store<D>
	return {
		maxStates = maxStates or ReplicationBodyStateTracker.DEFAULT_MAX_STATES,
		onCapped = onCapped,
		bodies = {},
		counters = { created = 0, replaced = 0, cleared = 0, expired = 0, capped = 0, refused = 0 },
	}
end

-- Drops this body's ended states and returns how many live states it still holds.
local function prune<D>(store: Store<D>, userId: number, nowMs: number): number
	local states = store.bodies[userId]
	if states == nil then
		return 0
	end
	local live = 0
	for key, entry in states do
		if ReplicationStateTimingUtils.isOver(entry.startMs, entry.durationMs, nowMs) then
			states[key] = nil
			if entry.durationMs ~= nil then
				store.counters.expired += 1
			else
				store.counters.capped += 1
				local onCapped = store.onCapped
				if onCapped ~= nil then
					onCapped(userId, entry)
				end
			end
		else
			live += 1
		end
	end
	if live == 0 then
		store.bodies[userId] = nil
	end
	return live
end

--[=[
	Set the state on `key`: replaces a live state on the same key, refuses a new key past `maxStates`.
]=]
function ReplicationBodyStateTracker.set<D>(
	store: Store<D>,
	userId: number,
	key: string,
	data: D,
	startMs: number,
	durationMs: number?,
	nowMs: number
): SetResult
	local live = prune(store, userId, nowMs)
	local states = store.bodies[userId]
	local replacing = states ~= nil and states[key] ~= nil
	if not replacing and live >= store.maxStates then
		store.counters.refused += 1
		return "full"
	end
	if states == nil then
		states = {}
		store.bodies[userId] = states
	end
	states[key] = { key = key, data = data, startMs = startMs, durationMs = durationMs }
	if replacing then
		store.counters.replaced += 1
		return "replaced"
	end
	store.counters.created += 1
	return "created"
end

--[=[
	The live state on `key`, or nil.
]=]
function ReplicationBodyStateTracker.get<D>(store: Store<D>, userId: number, key: string, nowMs: number): Entry<D>?
	prune(store, userId, nowMs)
	local states = store.bodies[userId]
	return if states ~= nil then states[key] else nil
end

--[=[
	End the live state on `key` early. Returns it (the shell owes its receivers a stop), or nil when the
	key held nothing live.
]=]
function ReplicationBodyStateTracker.clear<D>(store: Store<D>, userId: number, key: string, nowMs: number): Entry<D>?
	prune(store, userId, nowMs)
	local states = store.bodies[userId]
	if states == nil then
		return nil
	end
	local entry = states[key]
	if entry == nil then
		return nil
	end
	states[key] = nil
	if next(states) == nil then
		store.bodies[userId] = nil
	end
	store.counters.cleared += 1
	return entry
end

--[=[
	Drop every state on a body (death, respawn, slot switch, leave). Returns how many were dropped.
]=]
function ReplicationBodyStateTracker.clearBody<D>(store: Store<D>, userId: number): number
	local states = store.bodies[userId]
	if states == nil then
		return 0
	end
	local count = 0
	for _ in states do
		count += 1
	end
	store.bodies[userId] = nil
	store.counters.cleared += count
	return count
end

--[=[
	Every live state on a body, oldest first (ties by key): the replay list for a viewer it just entered.
]=]
function ReplicationBodyStateTracker.active<D>(store: Store<D>, userId: number, nowMs: number): { Entry<D> }
	prune(store, userId, nowMs)
	local list: { Entry<D> } = {}
	local states = store.bodies[userId]
	if states == nil then
		return list
	end
	for _, entry in states do
		table.insert(list, entry)
	end
	table.sort(list, function(a: Entry<D>, b: Entry<D>): boolean
		if a.startMs ~= b.startMs then
			return a.startMs < b.startMs
		end
		return a.key < b.key
	end)
	return list
end

--[=[
	States held across all bodies, including ended ones not yet pruned (a read-only count for F4).
]=]
function ReplicationBodyStateTracker.size<D>(store: Store<D>): number
	local count = 0
	for _, states in store.bodies do
		for _ in states do
			count += 1
		end
	end
	return count
end

return ReplicationBodyStateTracker
