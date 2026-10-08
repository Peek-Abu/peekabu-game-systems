--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local PlayerDataMigrationSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataMigrationSystem)
local PlayerDataPathUtils = require(ServerScriptService.Features.PlayerData.Utils.PlayerDataPathUtils)
local sift = require(ReplicatedStorage.Packages.sift)

--[=[
	Constants and configuration for the PlayerData system.
	@class PlayerDataConstants
]=]
-- THE slot switch. 1 = a single save per player (the default for most games: "slot-scoped" just
-- means "the player's save"). Raise it to give players multiple characters / save files: the data
-- layer (paths, epochs, the active-slot mirror gate) already handles any count, and the multi-slot
-- specs re-enable themselves once this is >= 2. A game that does so also needs a slot-switch flow
-- that bumps `slotState.epoch` (see PlayerDataTypes.SlotState).
local MAX_SLOTS = 1

-- Builds the empty slot array. Each slot is its OWN table: a single `{}` reused MAX_SLOTS times would
-- alias one table across all of them, so a write to slot 1 would appear in every other slot.
--
-- The slice fields are present but EMPTY: the skeleton owes the PlayerSlot type its declared fields,
-- while the actual defaults belong to the owning service's registration (CurrencyServiceServer's
-- `{ coins = 100 }`, …), which stamps over them at module load. That is what keeps this file free of
-- domain knowledge — and free of casts, since the annotated local supplies the type.
local function emptySlots(): { PlayerDataTypes.PlayerSlot }
	local slots: { PlayerDataTypes.PlayerSlot } = {}
	for index = 1, MAX_SLOTS do
		slots[index] = {
			currency = {},
			inventory = { items = {} },
			equippedTitle = {},
		}
	end
	return slots
end

-- The account skeleton, on the same terms as emptySlots: each field is declared (PlayerAccount
-- requires it) and its owning service registers the real default plus the data-layer validator.
--
-- itemMint and titles are stamped with their full shape rather than `{}` because their types require
-- those fields (an empty table would not typecheck). InventoryServiceServer still owns and validates
-- "itemMint", and TitleServiceServer owns "titles". `nextUid` starts at 1, not 0: uid 0 would be
-- indistinguishable from an absent/falsy value at any callsite that checks truthiness.
local function emptyAccount(): PlayerDataTypes.PlayerAccount
	return {
		itemMint = { nextUid = 1 },
		titles = { earned = {} },
	}
end

local PlayerDataConstants = {
	--[=[
		The number of save slots a profile carries (1 unless the game opts into multiple characters).
		@prop MAX_SLOTS number
	]=]
	MAX_SLOTS = MAX_SLOTS,

	--[=[
		Template for new player profiles. Domain services append their own slices via
		registerSlotPath / registerAccountPath; the skeleton below is what those slices hang off.
		New profiles are stamped with the current schema version so they skip migrations.
		@prop PROFILE_TEMPLATE PlayerDataTypes.PlayerProfile
	]=]
	PROFILE_TEMPLATE = {
		_schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION,
		-- A table, not a bare number: mutate() mutates the value at a path IN PLACE, so a scalar path
		-- would be unwritable — see PlayerDataTypes.SlotState.
		-- Declared here because PlayerProfile requires the field, but the value (and its data-layer
		-- validator) are OWNED by the registerRootPath("slotState", …) call at the bottom of this module,
		-- which stamps over it at load — the same "skeleton declares, registration owns" split as
		-- emptySlots / emptyAccount above.
		slotState = { active = 1, epoch = 1 },
		account = emptyAccount(),
		slots = emptySlots(),
	} :: PlayerDataTypes.PlayerProfile,
}

--[=[
	A per-slice invariant check run by PlayerDataService AFTER a mutator changes the slice, inside the
	locked region and before the write is committed/mirrored. Returns `true` when the resulting slice
	value is valid, or `false` plus a human-readable reason to reject the whole mutation (mutate() and
	transaction() then roll the slice back). This is what makes a cap like MAX_CURRENCY a real data-layer
	invariant rather than a service-method convention — a raw `transaction()` op that pushes a value
	out of range is rejected here regardless of which code path built it. Validators MUST be pure and
	synchronous (they run in the no-yield region; a yield would be a contract violation like a mutator's).
	@type PathValidator (value: any) -> (boolean, string?)
]=]
export type PathValidator = (value: any) -> (boolean, string?)

-- Optional invariant validators keyed by profile PATTERN (see PlayerDataPathUtils), populated by
-- registerSlotPath / registerAccountPath. A pattern with no entry (the default) is unvalidated —
-- mutate()/transaction() skip the check for it.
local pathValidators: { [string]: PathValidator } = {}

-- Every registered pattern key, so a double registration is caught even when the slice has no
-- validator (pathValidators alone would not notice).
local registered: { [string]: true } = {}

-- Every registered SLICE NAME, mapped to the pattern it was first registered under, and shared by
-- BOTH registrars. The `registered` set above is keyed by PATTERN, so it cannot see that
-- registerSlot("settings") and registerAccount("settings") are a collision: their patterns differ
-- (`slots.*.settings` vs `account.settings`) but the StateSyncServerStore atom is keyed by slice NAME, so both
-- would mirror into the SAME atom and the manifest's reader would silently pick one meaning. A slice
-- name is therefore globally unique across slot-scoped AND account-wide registration, enforced here.
local registeredSliceNames: { [string]: string } = {}

-- Once PlayerDataService consumes the template (init), further registration would silently omit a
-- slice from new profiles. Seal turns that latent bug into a loud error.
local sealed = false

--[=[
	Asserts that every field declared on the PROFILE_TEMPLATE skeleton (each PlayerSlot field, and
	each PlayerAccount field) has a registered owner — i.e. went through registerSlotPath /
	registerAccountPath. A declared-but-unregistered field would still ship to every player (the
	skeleton stamps it), but with no default owner, no data-layer validator, and no slice atom to
	mirror it — an "ownerless" slice, silently unvalidated.

	Separate from `seal()` (which calls this) so it can be exercised directly by a spec: `seal()` has
	no "unseal", so a test calling the real `seal()` would permanently lock out every OTHER spec's
	registerSlotPath / registerAccountPath calls for the rest of that TestEZ process run.
]=]
function PlayerDataConstants.assertAllSlicesOwned()
	-- PlayerSlot / PlayerAccount are exact-shaped records (no index signature), so generalized
	-- iteration over one gives back a key type Luau can't narrow to `string` for indexing
	-- `registeredSliceNames`. Field names are strings by construction, so `tostring` on the loop
	-- key is the identity conversion — no cast, no `any`, just an explicit runtime string coercion.
	for slotField in PlayerDataConstants.PROFILE_TEMPLATE.slots[1] do
		local fieldName = tostring(slotField)
		assert(
			registeredSliceNames[fieldName] ~= nil,
			`[PlayerDataConstants] slot field "{fieldName}" is declared in PlayerSlot but was never `
				.. "registered via registerSlotPath — this would ship an ownerless, unvalidated slice "
				.. "to every player."
		)
	end
	for accountField in PlayerDataConstants.PROFILE_TEMPLATE.account do
		local fieldName = tostring(accountField)
		assert(
			registeredSliceNames[fieldName] ~= nil,
			`[PlayerDataConstants] account field "{fieldName}" is declared in PlayerAccount but was `
				.. "never registered via registerAccountPath."
		)
	end
end

--[=[
	Freezes the profile template against further registration. Called by PlayerDataServiceServer
	once it has built the store from the template; any registerSlotPath / registerAccountPath after
	this errors.
	Idempotent.
]=]
function PlayerDataConstants.seal()
	PlayerDataConstants.assertAllSlicesOwned()
	sealed = true
end

-- Shared guard for both registrars. `patternKey` is the slot-index-agnostic key the validator is
-- stored under (see PlayerDataPathUtils): registering once must cover every slot.
local function assertRegisterable(patternKey: string, slice: string, validator: PathValidator?)
	assert(type(slice) == "string", "slice must be a string")
	assert(
		not sealed,
		`[PlayerDataConstants] Cannot register slice "{slice}" after the template is sealed `
			.. "(PlayerDataService already initialized). Require the owning service module during boot, "
			.. 'before initService("PlayerDataServiceServer").'
	)
	-- Reject by SLICE NAME (not just by pattern): a name registered as both slot-scoped and
	-- account-wide would collide on one StateSyncServerStore atom. The message names the SLICE, which is what
	-- the caller passed — the pattern is this module's internal key.
	assert(
		registered[patternKey] == nil and registeredSliceNames[slice] == nil,
		`[PlayerDataConstants] Slice "{slice}" is already registered (as "{registeredSliceNames[slice] or patternKey}"). `
			.. "A slice name must be unique across slot-scoped AND account-wide registration — both mirror "
			.. "into the StateSyncServerStore atom keyed by that name."
	)
	if validator ~= nil then
		assert(type(validator) == "function", `validator for slice "{slice}" must be a function, got {type(validator)}`)
		pathValidators[patternKey] = validator
	end
	registered[patternKey] = true
	registeredSliceNames[slice] = patternKey
end

-- Deep-copy so the template owns an independent table per destination. Callers pass literals
-- (e.g. { coins = 100 }); without this, every slot would alias ONE default table and a write to slot 1
-- would surface in the others. Scalars pass through untouched.
local function copyDefault(defaultData: any): any
	return if type(defaultData) == "table" then sift.Dictionary.copyDeep(defaultData) else defaultData
end

--[=[
	Registers a SLOT-SCOPED slice: one registration, stamped into every slot, validated in every slot.
	The owning service calls this via PlayerDataSliceSystem.registerSlot.
	@param slice string -- The slice name (e.g. "currency")
	@param defaultData any -- The initial value stamped into EACH slot of a new profile
	@param validator PathValidator? -- Invariant enforced by mutate()/transaction() on EVERY slot
]=]
function PlayerDataConstants.registerSlotPath(slice: string, defaultData: any, validator: PathValidator?)
	assertRegisterable(PlayerDataPathUtils.slotPattern(slice), slice, validator)
	for index = 1, MAX_SLOTS do
		PlayerDataConstants.PROFILE_TEMPLATE.slots[index][slice] = copyDefault(defaultData)
	end
end

--[=[
	Registers an ACCOUNT-WIDE slice. The owning service calls this via PlayerDataSliceSystem.registerAccount.
	@param slice string -- The slice name (e.g. "settings")
	@param defaultData any -- The initial value stamped onto new profiles
	@param validator PathValidator? -- Invariant enforced by mutate()/transaction()
]=]
function PlayerDataConstants.registerAccountPath(slice: string, defaultData: any, validator: PathValidator?)
	assertRegisterable(PlayerDataPathUtils.forAccount(slice), slice, validator)
	PlayerDataConstants.PROFILE_TEMPLATE.account[slice] = copyDefault(defaultData)
end

--[=[
	Registers a ROOT-KEY path: CORE profile state that is not a domain slice and therefore has no
	owning service (`slotState` — PlayerDataService and StateSyncSliceRegistry both read it, and neither may
	depend on a slot-switch service). The key is BARE (`slotState`, not `slots.*.x` / `account.x`), and
	PlayerDataPathUtils.pattern leaves a bare key unchanged, so the key IS its own registration pattern and
	`getValidator("slotState")` resolves what is registered here.

	Its whole point is the validator: without a registrar for bare keys, a root path was the ONE
	writable profile path with no data-layer invariant — `mutate(userId, "slotState", …)` (or a raw
	transaction op) could store any value at all, and the manifest reader would then index
	`profile.slots[<garbage>]` inside the locked commit region. Registering it here puts root state
	under exactly the same guarantee as every slice: the invariant holds for ANY path into it, not
	just the ones that go through the owning service's methods.

	Shares the `registered` / `registeredSliceNames` guards with the other two registrars, so a domain
	slice can never claim a name a root key already owns (both would key the same StateSyncServerStore atom).

	@param key string -- The bare root key (e.g. "slotState"); must contain no "."
	@param defaultData any -- The value stamped onto new profiles (a TABLE if the path must be writable:
		mutators mutate in place, so a scalar root path is read-only through the data layer)
	@param validator PathValidator? -- Invariant enforced by mutate()/transaction() on this key
]=]
function PlayerDataConstants.registerRootPath(key: string, defaultData: any, validator: PathValidator?)
	assert(type(key) == "string", "key must be a string")
	assert(not string.find(key, ".", 1, true), `[PlayerDataConstants] root key "{key}" must not contain "."`)
	assert(
		key ~= PlayerDataPathUtils.SLOTS and key ~= PlayerDataPathUtils.ACCOUNT,
		`[PlayerDataConstants] root key "{key}" is reserved by the profile skeleton`
	)
	assertRegisterable(key, key, validator)
	PlayerDataConstants.PROFILE_TEMPLATE[key] = copyDefault(defaultData)
end

--[=[
	Returns the invariant validator for a CONCRETE path, looked up by its PATTERN. This normalisation
	is load-bearing: a slice registers its validator once, and every slot must be covered by it. Keying
	the lookup on the concrete path would find the validator for slot 1 only, silently leaving any other
	slot unvalidated — precisely the class of bug the data-layer validator exists to prevent.
	@param path string -- A concrete profile path (e.g. "slots.2.currency")
	@return PathValidator? -- The validator, or nil if the slice is unvalidated
]=]
function PlayerDataConstants.getValidator(path: string): PathValidator?
	return pathValidators[PlayerDataPathUtils.pattern(path)]
end

-- The slotState invariant, enforced by the DATA LAYER on every write to the bare "slotState" path —
-- mutate()'s and a raw transaction() op's alike. It is what stops an out-of-range `active` from being
-- stored at all: every synced slice's manifest reader projects `profile.slots[slotState.active]`, so a
-- bad value would make the very next StateSyncServerStore.sync index nil INSIDE the locked commit region.
--
-- LIMITATION: this cannot check that `active` is a slot the player has UNLOCKED. A validator receives
-- only its own path's value, so a game with slot unlocks keeps "unlocked" as its slot-switch flow's
-- pre-flight guard. A cross-slice invariant would need a whole-profile validator, which the current
-- per-path validator contract deliberately does not have.
local function validateSlotState(slotState: PlayerDataTypes.SlotState): (boolean, string?)
	local active = slotState.active
	if type(active) ~= "number" then
		return false, `slotState.active must be a number, got {type(active)}`
	end
	if active ~= math.floor(active) then
		return false, `slotState.active must be an integer, got {active}`
	end
	if active < 1 or active > MAX_SLOTS then
		return false, `slotState.active {active} is out of range (1..{MAX_SLOTS})`
	end

	-- The epoch is a GENERATION counter (see PlayerDataTypes.SlotState), so it is bounded below by 1
	-- and by nothing above — deliberately NOT range-checked against MAX_SLOTS. A malformed epoch would
	-- silently break Task 2's staleness check (an op minted against a slot the player has since left
	-- would compare equal, or error), so the shape is enforced here, on every path into the key.
	local epoch = slotState.epoch
	if type(epoch) ~= "number" then
		return false, `slotState.epoch must be a number, got {type(epoch)}`
	end
	if epoch ~= math.floor(epoch) then
		return false, `slotState.epoch must be an integer, got {epoch}`
	end
	if epoch < 1 then
		return false, `slotState.epoch {epoch} must be >= 1`
	end
	return true
end

-- Registered by the CORE skeleton, not by a domain service: slotState is core profile state that
-- PlayerDataService (getActiveSlot, the mirror gate) and StateSyncSliceRegistry (every slot-scoped reader) both
-- read, and neither may depend on a slot-switch service — such a service depends on PlayerDataService,
-- so the reverse would invert the dependency. Registering it here also guarantees the validator exists no
-- matter which services a build happens to require.
PlayerDataConstants.registerRootPath("slotState", { active = 1, epoch = 1 }, validateSlotState)

return PlayerDataConstants
