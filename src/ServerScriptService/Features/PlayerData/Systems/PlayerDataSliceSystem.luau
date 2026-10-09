--!strict
--[=[
	PlayerDataSliceSystem: the shared scaffolding every service that owns a profile slice repeats.

	A "slice owner" (CurrencyServiceServer, InventoryServiceServer, a future QuestServiceServer, …)
	registers one slice on the profile and exposes read/mutate over it. Before this module each one
	hand-rolled the identical three-piece boilerplate: a path registration, a typed `getX`, and a
	one-line `_mutateX` wrapping `PlayerDataService:mutate(...)`. The DOMAIN logic (currency caps,
	inventory stacking) is genuinely different per service and stays in the service — only this
	scaffolding is shared.

	A slice is either SLOT-SCOPED (per character: currency, inventory, stats) or ACCOUNT-WIDE (shared
	by every character: entitlements, settings). That is the ONLY choice a service makes, and it makes
	it once, at registration. Everything downstream is identical:

	`registerSlot` resolves the player's ACTIVE slot at CALL time and builds the dotted path itself, so
	`get`/`mutate`/`op` have exactly the same shape as an account slice's. Domain services therefore
	never learn that slots exist at all — they read and write a plain `T` for "the character this
	player is currently playing", and a slot switch is invisible to them. Keeping that knowledge in
	this one file is what stops "which slot?" from leaking into every service that touches data.

	Both registrars are generic: the slice's value type `T` is inferred from the `read` closure — a
	typed field access on a PlayerSlot (`function(slot) return slot.currency end`) or a PlayerAccount —
	so `get` returns `T?` and `mutate`'s mutator argument is typed `T`, with ZERO casts. The closure
	takes the SLOT (not a whole profile) precisely so ONE closure can serve both `get` (the active
	slot) and `getForSlot` (any slot, for a slot-select preview) without narrowing anything. `default`
	is `unknown` (not `any`) purely because it forwards to the registrar's dynamic default; it does not
	participate in `T`'s inference, so it can't muddy the slice type.

	`get`/`mutate` look `PlayerDataService` up through the table at CALL time (not captured at require
	time), so the spec mock-strategy of patching `PlayerDataService._getSlotShell`/`.mutate` still works.

	@class PlayerDataSliceSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataPathUtils = require(PlayerDataServer.Utils.PlayerDataPathUtils)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)

--[=[
	Read/mutate access to one profile slice, typed to that slice's value.

	`get`/`mutate`/`op` are IDENTICAL in shape for slot-scoped and account-wide slices: a slot slice
	resolves the player's ACTIVE slot at call time. That is deliberate — domain services (CurrencyService,
	a future StatsService) never learn that slots exist; they read and write a plain `T` for "the
	character this player is currently playing".

	`op` is the one member with a timing contract on it: on a SLOT slice it bakes the player's active
	slot into the op at MINT time. Holding such an op across a yield (minting both legs of a trade,
	awaiting a confirmation RPC, then committing) is no longer a silent corruption — it is ENFORCED:
	the op also carries the slot generation it was minted under, and `transaction()` REJECTS the whole
	transaction if the player has switched character since. The interrupted trade is CANCELLED, not
	rerouted onto the wrong character. Raw hand-built op tables carry no stamp and are therefore NOT
	checked. See registerSlot's `op`.

	@interface SliceAccessor<T>
	.get (userId: number) -> T? -- The active slot's (or the account's) slice value; nil if the profile isn't loaded
	.getForSlot (userId: number, slotIndex: number) -> T? -- An explicit slot (slot-select preview); the account value on an account slice
	.mutate (userId: number, fn: (value: T) -> boolean?) -> (boolean, string?) -- Mutate the slice; fn returns true if it changed data. The second return is the validator's rejection reason, non-nil ONLY when a slice validator rejected the write.
	.op (userId: number, fn: (value: T) -> boolean) -> TransactionOperation -- Mint a typed transaction op over this slice; a slot slice captures the ACTIVE SLOT and its epoch at mint time, and transaction() refuses the op if the player has since switched character. Throws if the profile isn't loaded.
]=]
export type SliceAccessor<T> = {
	get: (userId: number) -> T?,
	getForSlot: (userId: number, slotIndex: number) -> T?,
	mutate: (userId: number, fn: (value: T) -> boolean?) -> (boolean, string?),
	op: (userId: number, fn: (value: T) -> boolean) -> PlayerDataService.TransactionOperation,
}

local PlayerDataSliceSystem = {}

--[=[
	Registers a SLOT-SCOPED slice (currency, inventory, stats, …) and returns typed access to it. Call
	once at the owning service's module load, so the slice is in the profile template before the first
	profile is loaded from it.

	Pass `validate` to make the slice's invariant a real data-layer guarantee: mutate()/transaction()
	run it after every mutator and roll back a write that violates it — including a raw transaction op
	that bypassed the owning service's own methods (e.g. a trade that would push a currency past its
	cap). It is registered once and enforced on EVERY slot (see PlayerDataPathUtils's pattern/concrete split),
	so a slice cannot be valid on the character you happened to test and unguarded on the other two.

	@param slice string -- The slice name this service owns (e.g. "currency")
	@param default unknown -- The initial value stamped into EVERY slot of a new profile
	@param read (slot: PlayerDataTypes.PlayerSlot) -> T -- Typed reader off ONE slot; drives the slice type T
	@param validate ((value: T) -> (boolean, string?))? -- Optional invariant enforced on every slot
	@return SliceAccessor<T> -- get/getForSlot/mutate/op over the slice, all typed to T
]=]
function PlayerDataSliceSystem.registerSlot<T>(
	slice: string,
	default: unknown,
	read: (slot: PlayerDataTypes.PlayerSlot) -> T,
	validate: ((value: T) -> (boolean, string?))?
): SliceAccessor<T>
	PlayerDataConstants.registerSlotPath(slice, default, validate)

	-- The concrete path to this slice IN THE PLAYER'S ACTIVE SLOT — nil when no profile is loaded.
	-- Derived per call, never cached: the active slot is a property of the session, not of the
	-- registration, and a slot switch must be picked up by the very next write.
	local function pathFor(userId: number): string?
		local activeSlot = PlayerDataService:getActiveSlot(userId)
		return if activeSlot then PlayerDataPathUtils.forSlot(slice, activeSlot) else nil
	end

	-- The shared body of `get` (active slot) and `getForSlot` (explicit slot) — they differ ONLY in
	-- how the slot index is found.
	--
	-- Per-slice shell (a frozen deep copy of ONLY this slice), not getProfile: a hot read like
	-- getCurrency must not pay a deep copy of every other slice (e.g. a large inventory). The shell is
	-- dropped immediately after the projection, per _getSlotShell's contract (its other fields alias
	-- LIVE profile tables and must not escape) — which is why this is the one place that touches it.
	local function readSlot(userId: number, slotIndex: number): T?
		local shell = PlayerDataService:_getSlotShell(userId, slotIndex, slice)
		if not shell then
			return nil
		end
		return read(shell)
	end

	return {
		get = function(userId)
			Guard.userId(userId)
			local activeSlot = PlayerDataService:getActiveSlot(userId)
			if not activeSlot then
				return nil
			end
			return readSlot(userId, activeSlot)
		end,

		getForSlot = function(userId, slotIndex)
			Guard.userId(userId)
			return readSlot(userId, slotIndex)
		end,

		mutate = function(userId, fn)
			Guard.userId(userId)
			local path = pathFor(userId)
			if not path then
				return false
			end
			return PlayerDataService:mutate(userId, path, fn)
		end,

		-- Mints a TransactionOperation over this slice with the mutator param typed T — the typed way
		-- to build `PlayerDataService:transaction()` ops (the raw form's mutator is untyped because
		-- TransactionOperation is inherently slice-generic; T erases here at the same documented
		-- boundary). Pure packaging: nothing runs until transaction() executes the op.
		--
		-- An op freezes the player's active slot at MINT time: the dotted path baked into it names ONE
		-- concrete slot, and transaction() later writes to THAT path — it never re-resolves the active
		-- slot (deliberately: addressing a specific slot on purpose is what makes atomic cross-slot
		-- moves possible). The exposed window is the caller-controlled one BETWEEN mint and
		-- transaction() — inside transaction()'s locked region nothing can interleave.
		--
		-- ENFORCED — a slot switch in that window no longer corrupts anything. We stamp the SLOT
		-- GENERATION the op is minted under, and transaction() REJECTS (in its side-effect-free
		-- validation phase, before any lock or mutator) any op whose epoch no longer matches the
		-- profile's. So the classic hazard — mint both legs of a trade, await the other player's
		-- confirmation, switch character in between, then commit to the character you just left, where
		-- the mirror gate also hides the write from the client — now fails the whole transaction
		-- instead. A trade interrupted by a character switch is CANCELLED, not rerouted.
		--
		-- NOT enforced: RAW hand-built op tables. Nothing stamps an epoch onto them, and an op with no
		-- epoch is never checked, so a raw op held across a switch still commits to the abandoned slot.
		-- The typed builders (this `op`, and the per-service wrappers over it — CurrencyService:currencyOp,
		-- InventoryService:inventoryOp) are the safe path; prefer them for anything held across a yield.
		--
		-- An unloaded profile has no active slot and so no path at all — assert rather than mint a
		-- bogus op, since transaction() is all-or-nothing and a silently dropped op would corrupt the
		-- other legs of the trade.
		--
		-- This op targets the player's ACTIVE slot (see `path` above), which is exactly why stamping the
		-- epoch is correct here: the active slot is the thing the epoch tracks. A future explicit
		-- `opForSlot(userId, slotIndex, fn)` that addresses a SPECIFIC (possibly non-active) slot must NOT
		-- inherit this stamp — the epoch would then reject a deliberate write to a slot the player has
		-- since switched away from, even though that write was never stale.
		op = function(userId, fn)
			Guard.userId(userId)
			local path = pathFor(userId)
			assert(path, `PlayerDataSliceSystem.op: no profile loaded for userId {userId}`)
			-- Stamp the generation this op is being minted under. Bound and asserted (not inlined) so this
			-- safety mechanism fails CLOSED: a nil epoch would otherwise mint an op that transaction()'s
			-- guard silently skips (nil epoch = unchecked, by design, for account-wide ops), i.e. the exact
			-- unchecked-slot-op bug this mechanism exists to prevent. Cannot be nil today — `path` above
			-- proves the profile is loaded, and epoch and active live in the same slotState table with no
			-- yield between the calls — but the guard exists for when that invariant breaks.
			-- See PlayerDataService.transaction's STALE-OP GUARD for what this buys.
			local epoch = PlayerDataService:getSlotEpoch(userId)
			assert(epoch, `PlayerDataSliceSystem.op: no slot epoch for userId {userId}`)
			return { userId = userId, path = path, mutator = fn, epoch = epoch }
		end,
	}
end

--[=[
	Registers an ACCOUNT-WIDE slice (settings, unlocked cosmetics, entitlement titles, …) and returns
	typed access to it. Same accessor shape as registerSlot — that symmetry is the point (see the class
	header). `getForSlot` returns the account value whatever slot is named, because an account slice is
	by definition the same for every character; that keeps a slot-select preview UI able to ask any
	slice for "slot N's value" without branching on how the slice was registered.

	Account slices hold ENTITLEMENTS ("you own this"), never quantities or item instances — see
	PlayerDataTypes.PlayerAccount for why.

	@param slice string -- The slice name (e.g. "settings")
	@param default unknown -- The initial value stamped onto new profiles
	@param read (account: PlayerDataTypes.PlayerAccount) -> T -- Typed reader off the account; drives the slice type T
	@param validate ((value: T) -> (boolean, string?))? -- Optional invariant enforced by mutate()/transaction()
	@return SliceAccessor<T> -- get/getForSlot/mutate/op over the slice, all typed to T
]=]
function PlayerDataSliceSystem.registerAccount<T>(
	slice: string,
	default: unknown,
	read: (account: PlayerDataTypes.PlayerAccount) -> T,
	validate: ((value: T) -> (boolean, string?))?
): SliceAccessor<T>
	PlayerDataConstants.registerAccountPath(slice, default, validate)
	-- Unlike a slot path, an account path has nothing session-dependent in it, so it is built once.
	local path = PlayerDataPathUtils.forAccount(slice)

	local function readAccount(userId: number): T?
		-- Per-slice shell (a frozen deep copy of ONLY this slice), not getProfile: a hot read must not
		-- pay a deep copy of every other slice. The shell is dropped immediately after the projection,
		-- per _getAccountShell's contract (its other fields alias live profile tables and must not
		-- escape). `slice` addresses it and `read` types it — paired here from one registration.
		local shell = PlayerDataService:_getAccountShell(userId, slice)
		if not shell then
			return nil
		end
		return read(shell)
	end

	return {
		get = function(userId)
			Guard.userId(userId)
			return readAccount(userId)
		end,

		getForSlot = function(userId, _slotIndex)
			Guard.userId(userId)
			return readAccount(userId)
		end,

		mutate = function(userId, fn)
			Guard.userId(userId)
			return PlayerDataService:mutate(userId, path, fn)
		end,

		-- See registerSlot.op. No slot to resolve here, so no unloaded-profile hazard: the path is
		-- valid for any userId, and transaction() rejects an unloaded profile itself.
		--
		-- And NO EPOCH STAMP, deliberately: account data is slot-independent, so a character switch
		-- cannot invalidate an op over it. Stamping one would fail perfectly valid transactions (e.g. a
		-- slot-unlock grant minted just before the player switches character). An op with no epoch is
		-- never epoch-checked by transaction().
		op = function(userId, fn)
			Guard.userId(userId)
			return { userId = userId, path = path, mutator = fn }
		end,
	}
end

return PlayerDataSliceSystem
