--!strict
--[=[
	StateSyncPublicPlayerStore: the server half of the public slice — per-player public facts that other
	clients may read (see PublicPlayerTypes).

	- One atom PER PLAYER for their public entry, and one shared ROSTER atom of every present player.
	- Relevance defaults to the roster: every viewer sees every present player, which suits small co-op and
	  lobby-sized servers. A game that needs less (teams, proximity, a huge server) calls `setRelevant` to
	  give a viewer an explicit set; `clearRelevant` returns it to the roster.
	- `getterFor(viewer)` is the charm-sync getter for `StateSyncConstants.publicKey(viewer)`. charm-sync runs
	  getters inside `Charm.effect`, so the getter re-runs exactly when the viewer's relevant set changes or
	  the entry of a player IN that set changes — never for players the viewer cannot see.
	- Entries are frozen snapshots: a write replaces the entry (new identity, so charm sees a change) and a
	  caller mutating its table afterwards changes nothing.

	StateSyncServiceServer calls `join` / `remove` as players arrive and leave; game code only calls `set`
	(and optionally `setRelevant`).

	@class StateSyncPublicPlayerStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)

type PublicPlayer = PublicPlayerTypes.PublicPlayer
type PublicPlayerMap = PublicPlayerTypes.PublicPlayerMap

local entries: { [number]: Charm.Atom<PublicPlayer?> } = {}
-- Explicit per-viewer relevance. nil (the default) means "use the roster".
local overrides: { [number]: Charm.Atom<{ number }?> } = {}
local initialRoster: { number } = {}
local roster = Charm.atom(table.freeze(initialRoster))

local StateSyncPublicPlayerStore = {}

local function entryAtom(userId: number): Charm.Atom<PublicPlayer?>
	local atom = entries[userId]
	if atom == nil then
		local initial: PublicPlayer? = nil
		atom = Charm.atom(initial)
		entries[userId] = atom
	end
	return atom
end

local function overrideAtom(viewerUserId: number): Charm.Atom<{ number }?>
	local atom = overrides[viewerUserId]
	if atom == nil then
		local initial: { number }? = nil
		atom = Charm.atom(initial)
		overrides[viewerUserId] = atom
	end
	return atom
end

local function frozenSorted(userIds: { number }): { number }
	local copy = table.clone(userIds)
	table.sort(copy)
	return table.freeze(copy)
end

--[=[
	The player arrived: they join the roster (so every roster viewer sees them) with an empty entry if
	they have none yet. Idempotent.
	@param userId number
]=]
function StateSyncPublicPlayerStore.join(userId: number)
	local current = roster()
	if table.find(current, userId) == nil then
		local nextRoster = table.clone(current)
		table.insert(nextRoster, userId)
		roster(frozenSorted(nextRoster))
	end
	local atom = entryAtom(userId)
	if atom() == nil then
		local empty: PublicPlayer = {}
		atom(table.freeze(empty))
	end
end

--[=[
	Merges `update` into the player's public entry: listed fields are overwritten, unlisted fields keep
	their value. Stores a frozen copy, so mutating `update` afterwards changes nothing.
	@param userId number
	@param update PublicPlayer -- the fields to write
]=]
function StateSyncPublicPlayerStore.set(userId: number, update: PublicPlayer)
	local atom = entryAtom(userId)
	local previous = atom()
	local snapshot: PublicPlayer = if previous ~= nil then table.clone(previous) else {}
	for field, value in update do
		snapshot[field] = value
	end
	atom(table.freeze(snapshot))
end

--[=[
	Removes one field from the player's public entry. A no-op when the entry or field is absent.
	@param userId number
	@param field string
]=]
function StateSyncPublicPlayerStore.clearField(userId: number, field: string)
	local atom = entries[userId]
	local previous = if atom ~= nil then atom() else nil
	if previous == nil or previous[field] == nil then
		return
	end
	local snapshot = table.clone(previous)
	snapshot[field] = nil
	entryAtom(userId)(table.freeze(snapshot))
end

function StateSyncPublicPlayerStore.get(userId: number): PublicPlayer?
	local atom = entries[userId]
	return if atom ~= nil then atom() else nil
end

--[=[
	The player left: their entry, their roster membership and their own relevance override go.
	@param userId number
]=]
function StateSyncPublicPlayerStore.remove(userId: number)
	local current = roster()
	local index = table.find(current, userId)
	if index ~= nil then
		local nextRoster = table.clone(current)
		table.remove(nextRoster, index)
		roster(frozenSorted(nextRoster))
	end
	local atom = entries[userId]
	if atom ~= nil then
		atom(nil)
		entries[userId] = nil
	end
	local viewerAtom = overrides[userId]
	if viewerAtom ~= nil then
		viewerAtom(nil)
		overrides[userId] = nil
	end
end

--[=[
	Gives a viewer an explicit relevant set (sorted, frozen copy) instead of the roster.
	@param viewerUserId number
	@param userIds { number }
]=]
function StateSyncPublicPlayerStore.setRelevant(viewerUserId: number, userIds: { number })
	overrideAtom(viewerUserId)(frozenSorted(userIds))
end

--[=[
	Returns a viewer to the default relevance (every present player).
	@param viewerUserId number
]=]
function StateSyncPublicPlayerStore.clearRelevant(viewerUserId: number)
	local atom = overrides[viewerUserId]
	if atom ~= nil then
		atom(nil)
	end
end

--[=[
	The players a viewer currently sees: their explicit set if one is given, else the roster.
	@param viewerUserId number
	@return { number }
]=]
function StateSyncPublicPlayerStore.relevantOf(viewerUserId: number): { number }
	local override = overrideAtom(viewerUserId)()
	return if override ~= nil then override else roster()
end

--[=[
	The charm-sync getter for one viewer's public map.
	@param viewerUserId number
	@return () -> PublicPlayerMap
]=]
function StateSyncPublicPlayerStore.getterFor(viewerUserId: number): () -> PublicPlayerMap
	return function(): PublicPlayerMap
		local result: PublicPlayerMap = {}
		for _, userId in StateSyncPublicPlayerStore.relevantOf(viewerUserId) do
			local entry = entryAtom(userId)()
			if entry ~= nil then
				result[StateSyncConstants.publicEntryKey(userId)] = entry
			end
		end
		return result
	end
end

return StateSyncPublicPlayerStore
