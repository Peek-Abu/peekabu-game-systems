--!strict
--[=[
	ProfileStoreTyped: a thin typed adapter (anti-corruption layer) over ProfileStore.

	WHY THIS EXISTS
	ProfileStore's published Luau types have gaps that otherwise force an `any` cast at every
	call site:
	  - `Profile.Data` / `LastSavedData` are typed `T & JSONAcceptable` (a scalar-or-table
	    union), so the checker won't treat your data as a plain record — breaking field access,
	    iteration, and exact-type matching.
	  - `StartSessionAsync`'s params type omits the runtime-valid `Cancel` callback, and its
	    receiver is typed `self: any`, which erases the generic so the result comes back untyped.
	  - the mock store is typed as a smaller variant than the real store, so it can't be stored
	    where a real store is expected.

	This module re-declares the slice of the API we actually use with CORRECT types and performs
	the SINGLE boundary cast (asserting ProfileStore conforms to that corrected interface — it
	does at runtime; only its published types disagree). Everything else imports these clean
	types, so the rest of the codebase has ZERO ProfileStore-related casts.

	@class ProfileStoreTyped
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local ProfileStoreRaw = require(ServerScriptService.ServerPackages.ProfileStore)

-- The concrete data shape this game stores. (Make these generic if you reuse the adapter
-- across multiple profile types.)
type Data = PlayerDataTypes.PlayerProfile

-- ProfileStore's signal shape, typed for the listeners we attach.
export type Connection = { Disconnect: (self: Connection) -> () }
type Signal<T...> = { Connect: (self: Signal<T...>, listener: (T...) -> ()) -> Connection }

export type Profile = {
	Data: Data,
	LastSavedData: Data,
	OnSave: Signal<>,
	OnAfterSave: Signal<Data>,
	OnSessionEnd: Signal<>,
	IsActive: (self: Profile) -> boolean,
	Reconcile: (self: Profile) -> (),
	EndSession: (self: Profile) -> (),
	AddUserId: (self: Profile, userId: number) -> (),
	Save: (self: Profile) -> (),
}

export type SessionParams = { Cancel: (() -> boolean)?, Steal: boolean? }

export type Store = {
	StartSessionAsync: (self: Store, profileKey: string, params: SessionParams?) -> Profile?,
	Mock: Store,
}

type Module = {
	New: (storeName: string, template: Data?) -> Store,
}

-- THE ONE BOUNDARY CAST. We assert ProfileStore conforms to the corrected module interface
-- above; it does at runtime — only its published types disagree. This is the single, labeled,
-- auditable `any` for the entire data layer.
local ProfileStore = (ProfileStoreRaw :: any) :: Module

local ProfileStoreTyped = {}

--[=[
	Creates a store with corrected types, returning the mock store when requested.
	@param storeName string -- The DataStore name
	@param template Data -- The profile template
	@param useMock boolean -- Use the in-memory mock store (tests / Studio)
	@return Store
]=]
function ProfileStoreTyped.new(storeName: string, template: Data, useMock: boolean): Store
	local store = ProfileStore.New(storeName, template)
	return if useMock then store.Mock else store
end

return ProfileStoreTyped
