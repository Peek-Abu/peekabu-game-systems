--!strict
--[=[
	StateSyncPublicPlayerStore: the server half of the public slice (spec Verdict, "Other players' public data rides
	charm-sync"; plan R2 Task 8).

	- One atom PER PLAYER for their public entry, and one atom PER VIEWER for the set of players relevant to
	  them (the bodies they have loaded, plus themselves — maintained by ReplicationServiceServer,
	  changed only on enter/leave).
	- `getterFor(viewer)` is the charm-sync getter for `StateSyncConstants.publicKey(viewer)`. charm-sync runs getters
	  inside `Charm.effect`, so the getter re-runs exactly when the viewer's relevant set changes or the entry
	  of a player IN that set changes — never for players the viewer cannot see, and never for movement.
	- Entries are frozen snapshots: a write replaces the entry (new identity, so charm sees a change) and a
	  caller mutating its table afterwards changes nothing.

	@class StateSyncPublicPlayerStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local sift = require(ReplicatedStorage.Packages.sift)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)

type PublicPlayer = PublicPlayerTypes.PublicPlayer
type PublicPlayerMap = PublicPlayerTypes.PublicPlayerMap

-- What a caller may overwrite; every field optional so the vitals publisher and the appearance
-- publisher can each patch THEIR fields without a stale read of the other's.
export type PublicPlayerUpdate = {
	health: number?,
	maxHealth: number?,
	appearance: PlayerDataTypes.Appearance?,
	appearanceVersion: number?,
}

local entries: { [number]: Charm.Atom<PublicPlayer?> } = {}
local relevant: { [number]: Charm.Atom<{ number }> } = {}
-- The highest appearance version each user has had on THIS server. It outlives `remove` on purpose: a viewer
-- keeps a rejoiner's old puppet and only re-dresses it for a newer version, so the sequence must keep
-- climbing across a leave. One number per user who ever joined, for the server's lifetime.
local lastVersions: { [number]: number } = {}

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

local function relevantAtom(viewerUserId: number): Charm.Atom<{ number }>
	local atom = relevant[viewerUserId]
	if atom == nil then
		local initial: { number } = {}
		atom = Charm.atom(initial)
		relevant[viewerUserId] = atom
	end
	return atom
end

-- Before any real publish, the entry is the same shape a slot-1 character starts with: a complete
-- but empty look on the standard default head type (same placeholder StateSyncClientStore uses pre-sync).
local placeholderAppearance: PlayerDataTypes.Appearance = sift.Dictionary.freezeDeep({
	cosmetics = {},
	accessories = {},
	body = {},
	headType = CustomizationCosmeticRegistry.DEFAULT_HEAD_TYPE,
	surfaces = {},
})

function StateSyncPublicPlayerStore.set(userId: number, update: PublicPlayerUpdate)
	local atom = entries[userId]
	local previous: PublicPlayer? = if atom ~= nil then atom() else nil
	local snapshot: PublicPlayer = {
		health = if update.health ~= nil then update.health elseif previous ~= nil then previous.health else 0,
		maxHealth = if update.maxHealth ~= nil
			then update.maxHealth
			elseif previous ~= nil then previous.maxHealth
			else 0,
		appearance = if update.appearance ~= nil
			then sift.Dictionary.freezeDeep(update.appearance)
			elseif previous ~= nil then previous.appearance
			else placeholderAppearance,
		appearanceVersion = if update.appearanceVersion ~= nil
			then update.appearanceVersion
			elseif previous ~= nil then previous.appearanceVersion
			else 0,
	}
	if snapshot.appearanceVersion > (lastVersions[userId] or 0) then
		lastVersions[userId] = snapshot.appearanceVersion
	end
	entryAtom(userId)(table.freeze(snapshot))
end

function StateSyncPublicPlayerStore.get(userId: number): PublicPlayer?
	local atom = entries[userId]
	return if atom ~= nil then atom() else nil
end

--[=[
	Publishes a new appearance for the user: deep-copies it into the entry and bumps the version past the
	highest this user has had on this server. It must NOT restart after a leave (found in staging): viewers
	that drew the player before keep that puppet and ignore any version not newer than the one it wears. A
	vitals-only `set` (which merges and preserves appearanceVersion) never disturbs it.
]=]
function StateSyncPublicPlayerStore.publish(userId: number, appearance: PlayerDataTypes.Appearance)
	local current = StateSyncPublicPlayerStore.get(userId)
	local base = math.max(if current ~= nil then current.appearanceVersion else 0, lastVersions[userId] or 0)
	local version = base + 1
	StateSyncPublicPlayerStore.set(userId, { appearance = appearance, appearanceVersion = version })
end

--[=[
	The player left: their entry and their own relevant set go. Viewers that still list them (none, once the
	replication service has processed the leave) would simply read nothing.
]=]
function StateSyncPublicPlayerStore.remove(userId: number)
	local atom = entries[userId]
	if atom ~= nil then
		atom(nil)
		entries[userId] = nil
	end
	local viewerAtom = relevant[userId]
	if viewerAtom ~= nil then
		local empty: { number } = {}
		viewerAtom(empty)
		relevant[userId] = nil
	end
end

--[=[
	Replace a viewer's relevant set (sorted, frozen copy). Called only on enter/leave.
]=]
function StateSyncPublicPlayerStore.setRelevant(viewerUserId: number, userIds: { number })
	local copy = table.clone(userIds)
	table.sort(copy)
	relevantAtom(viewerUserId)(table.freeze(copy))
end

function StateSyncPublicPlayerStore.relevantOf(viewerUserId: number): { number }
	local atom = relevant[viewerUserId]
	return if atom ~= nil then atom() else {}
end

--[=[
	The charm-sync getter for one viewer's public map.
]=]
function StateSyncPublicPlayerStore.getterFor(viewerUserId: number): () -> PublicPlayerMap
	local viewerAtom = relevantAtom(viewerUserId)
	return function(): PublicPlayerMap
		local result: PublicPlayerMap = {}
		for _, userId in viewerAtom() do
			local entry = entryAtom(userId)()
			if entry ~= nil then
				result[StateSyncConstants.publicEntryKey(userId)] = entry
			end
		end
		return result
	end
end

--[=[
	TEST SEAM: forgets every user's version history, so specs that remove and republish start from 1.
]=]
function StateSyncPublicPlayerStore._resetVersionsForTesting()
	table.clear(lastVersions)
end

return StateSyncPublicPlayerStore
