--!strict
--[=[
	StateSyncClientStore: the local player's reactive state, populated by charm-sync.

	These atoms are the client-side mirror of the server's StateSyncServerStore slices. StateSyncServiceClient
	registers them as charm-sync setters (via `setterFor`); the UI layer (React) reads them reactively
	with `useAtom`. The UI never writes here — the server is authoritative, and writes arrive only as
	charm-sync patches.

	Adding a synced slice here is two lines: declare its atom (narrowly typed — these are the values
	UI code consumes) and add one `atoms` registry entry closing over it. `setterFor`/`readSlice`
	derive from the registry, so neither grows a branch. The rest of the add-a-slice recipe lives in
	StateSyncSliceRegistry's header; the boot assert below catches a manifest/registry drift loudly.

	@class StateSyncClientStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)

-- nil until the first init payload arrives, so the UI can show a loading state.
local currency = Charm.atom(nil :: PlayerDataTypes.Currency?)
local inventory = Charm.atom({ items = {} } :: PlayerDataTypes.Inventory)
local titles = Charm.atom({ earned = {} } :: PlayerDataTypes.Titles) -- type the atom's initial value
local equippedTitle = Charm.atom({} :: PlayerDataTypes.EquippedTitle) -- type the atom's initial value
local premium = Charm.atom({ balance = 0 } :: PlayerDataTypes.Premium) -- type the atom's initial value
-- The public slice: other players' public data, already filtered by the server to the players relevant
-- to this client (plus this client itself). Not a profile slice; synced under StateSyncConstants.publicKey.
local initialPublicPlayers: PublicPlayerTypes.PublicPlayerMap = {}
local publicPlayers = Charm.atom(initialPublicPlayers)
-- The world slice: named entries about the match or server that every client syncs (StateSyncWorldStore).
-- Each owner's client decodes its own entry (e.g. RoundSnapshotUtils).
local initialWorld: WorldTypes.WorldMap = {}
local world = Charm.atom(initialWorld)

-- A charm-sync setter over one slice's atom. Inbound payload values arrive untyped from the wire,
-- so the setter surface is `unknown`; the atoms themselves (and every UI consumer) stay narrow.
export type SliceSetter = (value: unknown) -> ()

local StateSyncClientStore = {
	currency = currency,
	inventory = inventory,
	titles = titles,
	equippedTitle = equippedTitle,
	premium = premium,
	publicPlayers = publicPlayers,
	world = world,
}

-- The slice registry: one entry per synced slice, the atom itself (a Charm atom is callable both
-- ways: `atom()` reads, `atom(value)` writes). Values are type-erased at this generic boundary —
-- the registry is inherently string-keyed and dynamic (same documented rationale as StateSyncServerStore's
-- registry); narrow typing lives on the exported atoms above.
local atoms: { [string]: any } = {
	currency = currency,
	inventory = inventory,
	titles = titles,
	equippedTitle = equippedTitle,
	premium = premium,
	publicPlayers = publicPlayers,
	world = world,
}

-- Fail loudly at boot if the shared slice list (from StateSyncSliceRegistry) and this realm's registry ever
-- drift, rather than surfacing as a per-payload error the first time the server syncs an
-- unregistered slice.
for _, slice in StateSyncConstants.SLICES do
	assert(
		atoms[slice] ~= nil,
		`[StateSyncClientStore] "{slice}" is listed in StateSyncSliceRegistry but has no registered atom`
	)
end

--[=[
	Returns a charm-sync setter for a slice: a function that writes an inbound value into the
	matching atom. StateSyncServiceClient calls this while iterating `StateSyncConstants.SLICES`, so the
	slice→atom mapping lives here (next to the atoms) instead of being duplicated in the service.
	@param slice string -- The synced slice name (see StateSyncSliceRegistry)
	@return SliceSetter -- A charm-sync setter over this slice's atom
]=]
function StateSyncClientStore.setterFor(slice: string): SliceSetter
	local atom = atoms[slice]
	if not atom then
		error(`StateSyncClientStore has no synced slice "{slice}"`)
	end
	return function(value: unknown)
		atom(value)
	end
end

--[=[
	Reads the current value of a slice's atom by name. Generic counterpart to `setterFor`, used by the
	debug overlay to show the local player's client state slice-agnostically.
	@param slice string -- The synced slice name (see StateSyncSliceRegistry)
	@return unknown -- The slice's current atom value
]=]
function StateSyncClientStore.readSlice(slice: string): unknown
	local atom = atoms[slice]
	if not atom then
		error(`StateSyncClientStore has no synced slice "{slice}"`)
	end
	return atom()
end

return StateSyncClientStore
