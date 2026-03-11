--!strict
--[=[
	ClientStore: the local player's reactive state, populated by charm-sync.

	These atoms are the client-side mirror of the server's ServerStore slices. StateSyncServiceClient
	registers them as charm-sync setters (via `setterFor`); the UI layer (React) reads them reactively
	with `useAtom`. The UI never writes here — the server is authoritative, and writes arrive only as
	charm-sync patches.

	Adding a synced slice here is two lines: declare its atom (narrowly typed — these are the values
	UI code consumes) and add one `atoms` registry entry closing over it. `setterFor`/`readSlice`
	derive from the registry, so neither grows a branch. The rest of the add-a-slice recipe lives in
	SliceManifest's header; the boot assert below catches a manifest/registry drift loudly.

	@class ClientStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local SyncState = require(ReplicatedStorage.Shared.State.SyncState)

-- nil until the first init payload arrives, so the UI can show a loading state.
local currency = Charm.atom(nil :: PlayerDataTypes.Currency?)
local inventory = Charm.atom({} :: { PlayerDataTypes.InventoryItem })

-- A charm-sync setter over one slice's atom. Inbound payload values arrive untyped from the wire,
-- so the setter surface is `unknown`; the atoms themselves (and every UI consumer) stay narrow.
export type SliceSetter = (value: unknown) -> ()

local ClientStore = {
	currency = currency,
	inventory = inventory,
}

-- The slice registry: one entry per synced slice, the atom itself (a Charm atom is callable both
-- ways: `atom()` reads, `atom(value)` writes). Values are type-erased at this generic boundary —
-- the registry is inherently string-keyed and dynamic (same documented rationale as ServerStore's
-- registry); narrow typing lives on the exported atoms above.
local atoms: { [string]: any } = {
	currency = currency,
	inventory = inventory,
}

-- Fail loudly at boot if the shared slice list (from SliceManifest) and this realm's registry ever
-- drift, rather than surfacing as a per-payload error the first time the server syncs an
-- unregistered slice.
for _, slice in SyncState.SLICES do
	assert(atoms[slice] ~= nil, `[ClientStore] "{slice}" is listed in SliceManifest but has no registered atom`)
end

--[=[
	Returns a charm-sync setter for a slice: a function that writes an inbound value into the
	matching atom. StateSyncServiceClient calls this while iterating `SyncState.SLICES`, so the
	slice→atom mapping lives here (next to the atoms) instead of being duplicated in the service.
	@param slice string -- The synced slice name (see SliceManifest)
	@return SliceSetter -- A charm-sync setter over this slice's atom
]=]
function ClientStore.setterFor(slice: string): SliceSetter
	local atom = atoms[slice]
	if not atom then
		error(`ClientStore has no synced slice "{slice}"`)
	end
	return function(value: unknown)
		atom(value)
	end
end

--[=[
	Reads the current value of a slice's atom by name. Generic counterpart to `setterFor`, used by the
	debug overlay to show the local player's client state slice-agnostically.
	@param slice string -- The synced slice name (see SliceManifest)
	@return unknown -- The slice's current atom value
]=]
function ClientStore.readSlice(slice: string): unknown
	local atom = atoms[slice]
	if not atom then
		error(`ClientStore has no synced slice "{slice}"`)
	end
	return atom()
end

return ClientStore
