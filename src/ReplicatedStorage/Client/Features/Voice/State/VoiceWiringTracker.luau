--!strict
--[=[
	VoiceWiringTracker (R5 spec 2026-10-05 §2.3): which remote players' voice is wired, and the actions to take.
	Pure: the caller (VoiceServiceClient) performs each action on real instances.

	A player is wired when both exist: their replicated `VoiceInput` and their puppet's `Head`. Replacing
	either rewires (unwire, then wire). `clearHead` unwires only for the CURRENT head, so a stale despawn of an
	older puppet (a rejoin, a reuse) never cuts the live wiring. `remove` (the player left) unwires and
	forgets them.

	@class VoiceWiringTracker
]=]

local VoiceWiringTracker = {}

-- Approved at CP3: full volume to 10 studs, silent at 80.
local FALLOFF: { [number]: number } = { [0] = 1, [10] = 1, [45] = 0.35, [80] = 0 }
VoiceWiringTracker.FALLOFF = FALLOFF

export type Action =
	{ kind: "wire", userId: number, input: Instance, head: BasePart }
	| {
		kind: "unwire",
		userId: number,
	}

type Entry = { input: Instance?, head: BasePart?, wired: boolean }

export type State = { entries: { [number]: Entry } }

--[=[
	@return State
]=]
function VoiceWiringTracker.new(): State
	return { entries = {} }
end

local function entryFor(state: State, userId: number): Entry
	local entry = state.entries[userId]
	if entry == nil then
		entry = { input = nil, head = nil, wired = false }
		state.entries[userId] = entry
	end
	return entry
end

local function reconcile(entry: Entry, userId: number, changed: boolean): { Action }
	local actions: { Action } = {}
	if entry.wired and changed then
		local unwire: Action = { kind = "unwire", userId = userId }
		table.insert(actions, unwire)
		entry.wired = false
	end
	local input, head = entry.input, entry.head
	if not entry.wired and input ~= nil and head ~= nil then
		local wire: Action = { kind = "wire", userId = userId, input = input, head = head }
		table.insert(actions, wire)
		entry.wired = true
	end
	return actions
end

--[=[
	@param state State
	@param userId number
	@param input Instance? -- the player's `VoiceInput`, or nil when it is gone
	@return { Action }
]=]
function VoiceWiringTracker.setInput(state: State, userId: number, input: Instance?): { Action }
	local entry = entryFor(state, userId)
	local changed = entry.input ~= input
	entry.input = input
	return reconcile(entry, userId, changed)
end

--[=[
	@param state State
	@param userId number
	@param head BasePart? -- the puppet's `Head`, or nil (no head)
	@return { Action }
]=]
function VoiceWiringTracker.setHead(state: State, userId: number, head: BasePart?): { Action }
	local entry = entryFor(state, userId)
	local changed = entry.head ~= head
	entry.head = head
	return reconcile(entry, userId, changed)
end

--[=[
	The puppet that owned `head` despawned. Ignored unless `head` is the current one.
	@param state State
	@param userId number
	@param head BasePart
	@return { Action }
]=]
function VoiceWiringTracker.clearHead(state: State, userId: number, head: BasePart): { Action }
	local entry = state.entries[userId]
	if entry == nil or entry.head ~= head then
		return {}
	end
	entry.head = nil
	return reconcile(entry, userId, true)
end

--[=[
	The player left: unwire and forget them.
	@param state State
	@param userId number
	@return { Action }
]=]
function VoiceWiringTracker.remove(state: State, userId: number): { Action }
	local entry = state.entries[userId]
	state.entries[userId] = nil
	if entry == nil or not entry.wired then
		return {}
	end
	local unwire: Action = { kind = "unwire", userId = userId }
	return { unwire }
end

--[=[
	@param state State
	@return number
]=]
function VoiceWiringTracker.wiredCount(state: State): number
	local count = 0
	for _, entry in state.entries do
		if entry.wired then
			count += 1
		end
	end
	return count
end

return VoiceWiringTracker
