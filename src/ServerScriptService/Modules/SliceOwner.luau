--!strict
--[=[
	SliceOwner: the shared scaffolding every service that owns a profile slice repeats.

	A "slice owner" (CurrencyServiceServer, InventoryServiceServer, a future QuestServiceServer, …)
	registers one root key on the profile and exposes read/mutate over it. Before this module each
	one hand-rolled the identical three-piece boilerplate: `registerProfilePath`, a typed `getX`, and
	a one-line `_mutateX` wrapping `PlayerDataService:mutate(userId, "<slice>", fn)`. The DOMAIN logic
	(currency caps, inventory stacking) is genuinely different per service and stays in the service —
	only this scaffolding is shared.

	`register` is generic: the slice's value type `T` is inferred from the `read` closure (a typed
	field access like `function(p) return p.currency end`, the same read-fn shape `ServerStore` uses),
	so `get` returns `T?` and `mutate`'s mutator argument is typed `T` — with ZERO casts. `default` is
	`unknown` (not `any`) purely because it forwards to `registerProfilePath`'s dynamic default; it does
	not participate in `T`'s inference, so it can't muddy the slice type.

	`get`/`mutate` look `PlayerDataService` up through the table at CALL time (not captured at require
	time), so the spec mock-strategy of patching `PlayerDataService._getSliceShell`/`.mutate` still works.

	@class SliceOwner
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local Guard = require(ReplicatedStorage.Shared.Modules.Guard)
local PlayerDataConstants = require(ServerScriptService.Modules.Constants.PlayerDataConstants)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService.PlayerDataServiceServer)

--[=[
	Read/mutate access to one profile slice, typed to that slice's value.
	@interface SliceAccessor<T>
	.get (userId: number) -> T? -- The player's slice value, or nil if their profile isn't loaded
	.mutate (userId: number, fn: (value: T) -> boolean?) -> boolean -- Mutate the slice; fn returns true if it changed data
	.op (userId: number, fn: (value: T) -> boolean) -> TransactionOperation -- Mint a typed transaction op over this slice
]=]
export type SliceAccessor<T> = {
	get: (userId: number) -> T?,
	mutate: (userId: number, fn: (value: T) -> boolean?) -> boolean,
	op: (userId: number, fn: (value: T) -> boolean) -> PlayerDataService.TransactionOperation,
}

local SliceOwner = {}

--[=[
	Registers a profile slice and returns typed read/mutate access to it. Call once at the owning
	service's module load.

	Pass `validate` to make the slice's invariant a real data-layer guarantee: mutate()/transaction()
	run it after every mutator and roll back a write that violates it — including a raw transaction op
	that bypassed the owning service's own methods (e.g. a trade that would push a currency past its
	cap). The validator is typed to the slice value `T`, so the check reads its fields with no cast.

	@param slice string -- The root profile key this service owns (e.g. "currency")
	@param default unknown -- The initial value stamped onto new profiles for this key
	@param read (profile: PlayerDataTypes.PlayerProfile) -> T -- Typed reader off a full profile; drives the slice type T
	@param validate ((value: T) -> (boolean, string?))? -- Optional invariant enforced by mutate()/transaction()
	@return SliceAccessor<T> -- get/mutate over the slice, both typed to T
]=]
function SliceOwner.register<T>(
	slice: string,
	default: unknown,
	read: (profile: PlayerDataTypes.PlayerProfile) -> T,
	validate: ((value: T) -> (boolean, string?))?
): SliceAccessor<T>
	PlayerDataConstants.registerProfilePath(slice, default, validate)

	return {
		get = function(userId)
			Guard.userId(userId)
			-- Per-slice snapshot (frozen deep copy of ONLY this slice), not getProfile: a hot read
			-- like getCurrency must not pay a deep copy of every other slice (e.g. a large
			-- inventory). `slice` addresses it, `read` types it — paired here from one registration.
			-- The shell is dropped immediately after the projection, per _getSliceShell's contract
			-- (its other fields alias live profile tables and must not escape).
			local shell = PlayerDataService:_getSliceShell(userId, slice)
			if not shell then
				return nil
			end
			return read(shell)
		end,

		mutate = function(userId, fn)
			Guard.userId(userId)
			return PlayerDataService:mutate(userId, slice, fn)
		end,

		-- Mints a TransactionOperation over this slice with the mutator param typed T — the typed
		-- way to build `PlayerDataService:transaction()` ops (the raw form's mutator is untyped
		-- because TransactionOperation is inherently slice-generic; T erases here at the same
		-- documented boundary). Pure packaging: nothing runs until transaction() executes the op.
		op = function(userId, fn)
			Guard.userId(userId)
			return { userId = userId, path = slice, mutator = fn }
		end,
	}
end

return SliceOwner
