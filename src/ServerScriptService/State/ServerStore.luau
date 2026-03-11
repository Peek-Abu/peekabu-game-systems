--!strict
--[=[
	ServerStore: the server-authoritative reactive mirror of player data.

	This is the bridge between the existing data layer (ProfileStore profiles, mutated only
	through `PlayerDataServiceServer:mutate()`/`:transaction()`) and charm-sync replication.
	The data layer stays the source of truth; after any committed write it pushes the affected
	slice in here as a Charm atom, and charm-sync diffs the atom and ships only the delta to
	the owning client. No per-feature broadcast packet is needed — state flows
	profile -> atom -> charm-sync -> client atom -> UI.

	Each slice is a single atom holding a `{ [userId]: value }` map (charm-sync registers one
	per-player getter that reads its own entry). Writes store a DEEP COPY of the value: the
	live profile tables are mutated in place by `mutate()`, so without a copy the atom would
	alias the profile and charm-sync's diff (old snapshot vs. new) would see no change and
	replicate nothing.

	The slice registry is built ENTIRELY from `SliceManifest` — one atom per manifest entry,
	mirrored through that entry's `read`. Adding a synced slice never touches this file (see
	SliceManifest's header for the full add-a-slice recipe). Atom values are type-erased at this
	generic boundary (the registry is inherently string-keyed and dynamic — same rationale as
	`ProfilePath` being `string`, see limitations.md #3); narrow typing lives with the slice's
	consumers (the owning service's SliceOwner accessor, `ClientStore`'s atoms).

	@class ServerStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local sift = require(ReplicatedStorage.Packages.sift)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local SliceManifest = require(ReplicatedStorage.Shared.State.SliceManifest)

type Currency = PlayerDataTypes.Currency
type InventoryItem = PlayerDataTypes.InventoryItem

-- The slice registry, built from the manifest: one entry per synced slice, pairing a fresh atom
-- with the manifest's reader off a full profile. `syncFromProfile`/`getterFor`/`remove` iterate
-- this table generically, so none of them grow a branch when a slice is added.
local slices: { [string]: { atom: Charm.Atom<{ [number]: any }>, read: (PlayerDataTypes.PlayerProfile) -> any } } = {}
for name, definition in SliceManifest.DEFINITIONS do
	slices[name] = {
		atom = Charm.atom({}),
		read = definition.read,
	}
end

local ServerStore = {}

-- Named atom conveniences for the two built-in slices, exposed for specs and debug tooling.
-- NOT required for new slices — generic access goes through `getterFor`/`snapshot`.
ServerStore.currencies = slices.currency.atom
ServerStore.inventories = slices.inventory.atom

local function findSlice(slice: string)
	local entry = slices[slice]
	if not entry then
		error(`ServerStore has no synced slice "{slice}"`)
	end
	return entry
end

local function setSlice(slice: string, userId: number, value: any)
	local entry = findSlice(slice)
	local snapshot = sift.Dictionary.copyDeep(value)
	entry.atom(function(state)
		local updated = table.clone(state)
		updated[userId] = snapshot
		return updated
	end)
end

--[=[
	Stores a player's currency snapshot, replacing the per-user map immutably so charm
	observes a change. The value is deep-copied to decouple it from the live profile table.
	Convenience over `set` for the built-in slice; not an edit site for new slices.
	@param userId number -- The owning player's UserId
	@param currency Currency -- The currency slice to mirror
]=]
function ServerStore.setCurrency(userId: number, currency: Currency)
	setSlice("currency", userId, currency)
end

--[=[
	Stores a player's inventory snapshot (deep-copied, same rationale as setCurrency).
	Convenience over `set` for the built-in slice; not an edit site for new slices.
	@param userId number -- The owning player's UserId
	@param inventory { InventoryItem } -- The inventory slice to mirror
]=]
function ServerStore.setInventory(userId: number, inventory: { InventoryItem })
	setSlice("inventory", userId, inventory)
end

--[=[
	Stores a player's snapshot for any registered slice (deep-copied). The generic counterpart to
	the named conveniences above — new slices use this without ServerStore growing a function.
	@param slice string -- The synced slice name (see SliceManifest)
	@param userId number -- The owning player's UserId
	@param value unknown -- The slice value to mirror
]=]
function ServerStore.set(slice: string, userId: number, value: unknown)
	setSlice(slice, userId, value)
end

--[=[
	Returns the current `{ [userId]: value }` map for a slice (the atom's value, identity-stable
	between writes). Generic read counterpart to `set`, used by specs and debug tooling.
	@param slice string -- The synced slice name (see SliceManifest)
	@return { [number]: unknown } -- The per-user snapshot map
]=]
function ServerStore.snapshot(slice: string): { [number]: unknown }
	return findSlice(slice).atom()
end

--[=[
	Mirrors a single slice of a profile into the store. Called from PlayerDataServiceServer after a
	committed `mutate()`/`transaction()` op, so only the slice that actually changed re-mirrors —
	not the whole profile. A no-op-free error on an unregistered slice; callers should check
	`isSyncedSlice` first for a path that might not be a synced one (see limitations.md #3).
	@param slice string -- The synced slice name (see SliceManifest)
	@param userId number -- The owning player's UserId
	@param profile PlayerDataTypes.PlayerProfile -- The player's profile data
]=]
function ServerStore.sync(slice: string, userId: number, profile: PlayerDataTypes.PlayerProfile)
	local entry = findSlice(slice)
	setSlice(slice, userId, entry.read(profile))
end

--[=[
	True if `slice` is a registered synced slice. `PlayerDataServiceServer` checks this before
	calling `sync()` with a mutated profile path, since not every path is necessarily replicated.
	@param slice string -- A profile path / potential slice name
	@return boolean
]=]
function ServerStore.isSyncedSlice(slice: string): boolean
	return slices[slice] ~= nil
end

--[=[
	Mirrors a full profile into the store: every registered slice, one at a time. Called from
	PlayerDataServiceServer on initial profile load, when the client needs full state for every
	slice at once. Generic over the slice registry, so a new slice needs no new call here.
	@param userId number -- The owning player's UserId
	@param profile PlayerDataTypes.PlayerProfile -- The player's profile data
]=]
function ServerStore.syncFromProfile(userId: number, profile: PlayerDataTypes.PlayerProfile)
	for slice in slices do
		ServerStore.sync(slice, userId, profile)
	end
end

--[=[
	Returns a charm-sync getter for a slice: a zero-arg function reading the given user's snapshot
	from the matching atom. StateSyncServiceServer calls this while iterating `SyncState.SLICES`, so
	the slice→atom mapping lives here (next to the atoms) instead of being duplicated in the service.
	@param slice string -- The synced slice name (see SliceManifest)
	@param userId number -- The owning player's UserId
	@return () -> unknown -- A charm-sync getter over this user's slice
]=]
function ServerStore.getterFor(slice: string, userId: number): () -> unknown
	local entry = findSlice(slice)
	return function()
		return entry.atom()[userId]
	end
end

--[=[
	Drops a player's mirrored state when they leave. Generic over the slice registry.
	@param userId number -- The departing player's UserId
]=]
function ServerStore.remove(userId: number)
	for _, entry in slices do
		entry.atom(function(state)
			if state[userId] == nil then
				return state
			end
			local updated = table.clone(state)
			updated[userId] = nil
			return updated
		end)
	end
end

return ServerStore
