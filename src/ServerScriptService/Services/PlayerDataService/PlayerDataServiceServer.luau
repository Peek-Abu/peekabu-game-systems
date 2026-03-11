--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Observers = require(ReplicatedStorage.Packages.Observers)
local ServiceController = require(ReplicatedStorage.Shared.Modules.ServiceController)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local ProfileStoreTyped = require(ServerScriptService.Modules.ProfileStoreTyped)
local PlayerDataMigrations = require(ServerScriptService.Modules.PlayerDataMigrations)
local PlayerDataConstants = require(ServerScriptService.Modules.Constants.PlayerDataConstants)
local ServerStore = require(ServerScriptService.State.ServerStore)
local sift = require(ReplicatedStorage.Packages.sift)
local log = Logger.new("PlayerDataServiceServer")

local janitor = Janitor.new()

-- Deep-freezes a profile snapshot generically — every table at every level, whatever slices are
-- registered — so getProfile can hand out a read-only copy (see getProfile) and a NEW slice added
-- via SliceOwner.register inherits that protection with no edit here. sift's freezeDeep builds a
-- frozen deep COPY (the live table is never touched), so it also subsumes getProfile's separate
-- copyDeep: one traversal instead of two. freezeDeep is published as AnyDictionary -> AnyDictionary,
-- so this wrapper is the single place the profile type is re-asserted on the way out — the same
-- single-labeled-boundary philosophy as ProfileStoreTyped, with no written cast at the call site.
local function freezeProfileSnapshot(data: PlayerDataTypes.PlayerProfile): PlayerDataTypes.PlayerProfile
	return sift.Dictionary.freezeDeep(data)
end

-- Commit-save retry policy for transaction(): attempts per profile and the linear backoff base
-- between them. A commit that still fails after these attempts leaves the transaction committed in
-- memory (the normal auto-save retries it) and reports the userId via TransactionResult.failedUserIds
-- so economy-critical callers can react instead of trusting a bare success.
local TRANSACTION_COMMIT_SAVE_ATTEMPTS = 3
local TRANSACTION_COMMIT_RETRY_BASE_SECONDS = 0.5

-- How long each persist attempt waits for the profile's OnAfterSave before treating the save as
-- unconfirmed. ProfileStore's Save() only DISPATCHES the write (it re-slots the auto-save queue and
-- task.spawns the actual UpdateAsync, returning immediately — ProfileStore.luau:1172), so a clean
-- Save() return proves nothing about durability; OnAfterSave fires only once the UpdateAsync has
-- actually landed. Overridable per test run via _setPersistConfirmTimeoutForTesting so specs never
-- stall on the production timeout.
local TRANSACTION_COMMIT_CONFIRM_TIMEOUT_SECONDS = 10
local persistConfirmTimeoutOverride: number? = nil

local playerProfiles: { [number]: ProfileStoreTyped.Profile } = {}

-- Per-player cleanup scopes for session-scoped connections (OnSave, OnSessionEnd).
-- Destroyed when the player leaves or their session ends, so connections never
-- accumulate across sessions on the long-lived module-level `janitor`.
-- Typed as `typeof(janitor)` (the concrete instance above) rather than
-- `typeof(Janitor.new())` or the package's `Janitor` alias. Janitor's exported type has
-- generic methods (`Add<T>`); under luau-lsp's invariant self-check, a value read back
-- out of a table field annotated with that generic type fails to match its own method
-- selves ("Expected Janitor, got Janitor"). The already-instantiated `typeof(janitor)`
-- sidesteps that, and method calls (`:Destroy()`) check cleanly.
local playerJanitors: { [number]: typeof(janitor) } = {}

-- Whether the store was created against ProfileStore's in-memory mock (Studio) rather than live
-- DataStores. Captured at init purely for getState's diagnostics — "why isn't my data persisting"
-- is answered instantly when the debugger shows the store is mocked.
local usingMockStore = false

-- Tracks profiles currently in a transaction for auto-save abort detection: while a profile is in
-- here, an OnSave firing is a mid-transaction auto-save and flips `aborted` so the apply loop rolls
-- back from the in-memory snapshot (transaction() takes no forced pre-save — see its Phase 2).
local profilesInTransaction: { [number]: { aborted: boolean } } = {}

-- Set while ANY mutator (mutate()'s or a transaction() op's) is executing; mutators are synchronous
-- (enforced), so a plain flag suffices. This closes the nesting hole the per-profile re-entry guard
-- cannot see: that guard only refuses a nested call on an AFFECTED profile, but a mutator calling
-- mutate()/transaction() on a profile the outer transaction does NOT touch would commit (and mirror)
-- immediately — and if the outer transaction later rolls back, that third profile's write is in no
-- snapshot and survives, silently breaking all-or-nothing (e.g. a trade whose op paid an escrow
-- profile, then aborted: participants roll back, the escrow keeps the payment). So every nested
-- data-layer write from inside a mutator is refused, affected profile or not. Mutators stay pure
-- slice edits; compose multi-profile writes as sibling ops of ONE transaction instead of nesting.
local mutatorInFlight = false

-- The auto-save abort handler, shared by live sessions (wired in onPlayerAdded) and the
-- _setProfileForTesting seam — one definition so specs that fire a fake profile's OnSave exercise
-- the REAL abort machinery.
--
-- An OnSave firing while a profile is mid-transaction should be IMPOSSIBLE in production: the
-- locked region is fully synchronous (mutators can't yield — enforced), so ProfileStore's save
-- loop never gets a scheduler turn between lock and commit. If we ever observe it, a yield has
-- leaked into the locked region — a bug. We flag `aborted` (so the transaction still bails and
-- rolls back its in-memory snapshot rather than committing a half-applied state) and log LOUDLY so
-- the regression surfaces. We deliberately do NOT reset the whole `Data` table here: the earlier
-- version did (`Data = copyDeep(LastSavedData)`), which — if this path ever ran — would also
-- silently discard unsaved writes to slices this transaction never touched. rollbackAll already
-- restores exactly the touched paths from their snapshots, which is the correct, loss-free scope.
local function onProfileAutoSave(userId: number)
	local txnState = profilesInTransaction[userId]
	if txnState and not txnState.aborted then
		txnState.aborted = true
		log:error(
			"Auto-save fired for a profile mid-transaction — this should be impossible (the locked "
				.. "region must stay yield-free). Aborting the transaction to avoid a partial commit. userId:",
			userId
		)
	end
end

-- OnSave connections created by the _setProfileForTesting seam, keyed by userId and disconnected
-- when a seeded profile is cleared, so fake profiles never leak handlers across specs.
local testSeamSaveConnections: { [number]: ProfileStoreTyped.Connection } = {}

export type TransactionOperation = {
	userId: number,
	path: PlayerDataTypes.ProfilePath,
	mutator: (data: any) -> boolean, -- Return false to abort transaction
}

--[=[
	The narrow player surface the session lifecycle actually needs, so _startSession can be
	unit-tested without a live Player instance (Players can't be Instance.new'd, in Studio or the
	Open Cloud test runtime). onPlayerAdded adapts the real Player into this shape; specs pass a
	fake that records kicks and toggles presence.
]=]
export type SessionHost = {
	userId: number,
	name: string,
	isPresent: () -> boolean,
	kick: (message: string) -> (),
}

--[=[
	Options for transaction().
	- persist: force an immediate durable save (with bounded retries) once the transaction commits in
	  memory. Omit/false (the default) commits in memory only and lets the normal ProfileStore
	  auto-save persist it — the same durability model as mutate(). Pass true for economy-critical
	  writes (trades) where the caller must confirm the write landed this server before proceeding.
]=]
export type TransactionOptions = {
	persist: boolean?,
}

--[=[
	Structured outcome of transaction(), returned alongside the boolean for callers that need to
	distinguish "committed in memory" from "durably persisted".
	- committed: every mutator applied and the transaction committed in memory (== the boolean return).
	- persisted: true only when the call was `{ persist = true }` AND every affected profile's save
	  was CONFIRMED durable on THIS server — the profile's OnAfterSave fired after the dispatched
	  save, meaning the UpdateAsync actually landed (Save() alone only dispatches; see the commit
	  phase). A default (in-memory) transaction always reports `persisted = false`: it is committed
	  but not yet durable — the next auto-save writes it.
	- failedUserIds: users whose persist-save threw, or was dispatched but never confirmed by
	  OnAfterSave within the timeout, after all retries. Their data IS committed in memory and the
	  normal auto-save will retry the write; treat a non-empty list as "not yet durable".
	  Always empty for a default transaction (no save was attempted).
]=]
export type TransactionResult = {
	committed: boolean,
	persisted: boolean,
	failedUserIds: { number },
}

--[=[
	Public interface of the service — the single place method/field types are declared.
	See ServiceController's header for the standard service-module shape (lean annotated
	literal). `PlayerStore` is a declared field (set during init), which removes the old
	`typeof(self) & { PlayerStore }` intersection and the return-cast it required.
]=]
export type PlayerDataServiceServer = {
	PlayerStore: ProfileStoreTyped.Store?,

	init: (self: PlayerDataServiceServer, configs: PlayerDataTypes.PlayerDataServiceConfigs) -> (),
	onPlayerAdded: (self: PlayerDataServiceServer, player: Player) -> (),
	_startSession: (self: PlayerDataServiceServer, host: SessionHost) -> (),
	onPlayerRemoving: (self: PlayerDataServiceServer, player: Player) -> (),
	_cleanupPlayer: (self: PlayerDataServiceServer, userId: number) -> (),
	getProfile: (self: PlayerDataServiceServer, userId: number) -> PlayerDataTypes.PlayerProfile?,
	_getSliceShell: (
		self: PlayerDataServiceServer,
		userId: number,
		path: PlayerDataTypes.ProfilePath
	) -> PlayerDataTypes.PlayerProfile?,
	mutate: <T>(
		self: PlayerDataServiceServer,
		userId: number,
		path: PlayerDataTypes.ProfilePath,
		mutator: (data: T) -> boolean?
	) -> boolean,
	transaction: (
		self: PlayerDataServiceServer,
		operations: { TransactionOperation },
		options: TransactionOptions?
	) -> (boolean, TransactionResult),
	stop: (self: PlayerDataServiceServer) -> (),
	getState: (self: PlayerDataServiceServer) -> { [string]: any },
	_setProfileForTesting: (self: PlayerDataServiceServer, userId: number, profile: ProfileStoreTyped.Profile?) -> (),
	_setPersistConfirmTimeoutForTesting: (self: PlayerDataServiceServer, seconds: number?) -> (),
}

local PlayerDataServiceServer: PlayerDataServiceServer = {
	-- Set during init() once the store is created; nil until then.
	PlayerStore = nil,

	--[=[
		Initializes the PlayerDataServiceServer and sets up event connections.
		@param self PlayerDataServiceServer -- The service instance
	]=]
	init = function(self, configs)
		-- Profile template is now dynamically assembled by domain services via `PlayerDataConstants.registerProfilePath`
		-- before this init method is called.
		log:debug("Initialized with template:", configs.template)

		usingMockStore = configs.useMock == true
		self.PlayerStore = ProfileStoreTyped.new(configs.storeName, configs.template, configs.useMock)
		-- Template is now consumed; forbid further registerProfilePath so a late-required slice owner
		-- fails loudly instead of silently missing from new profiles. Only sealed in a shippable build:
		-- the test build (default.project.json) runs ServerHandler alongside TestRunner, and specs like
		-- SliceOwner.spec register synthetic slices at module-load time that would race the seal. The
		-- presence of DevPackages/TestEZ is the reliable "test build" signal — production.project.json
		-- omits it, and a production place has no specs, so sealing there is safe and catches the real bug.
		if not ReplicatedStorage:FindFirstChild("DevPackages") then
			PlayerDataConstants.seal()
		end
		janitor:Add(
			Observers.observePlayer(function(player)
				self:onPlayerAdded(player)
				return function()
					self:onPlayerRemoving(player)
				end
			end),
			true
		)
	end,

	--[=[
		Handles when a player joins the game and loads their profile.

		Kick Behavior:
		Players are kicked on profile load failure or session end. This is the recommended
		Roblox pattern for data persistence because:
		1. Prevents exploits: Players without valid profiles could bypass game systems
		2. Handles network issues: DataStore failures are often transient; rejoining retries
		3. Session locking: ProfileStore uses session locks to prevent data corruption from
		   multiple servers. If another server holds the lock, kicking lets them rejoin
		   to the correct server or wait for lock release
		4. Data integrity: Playing without a profile risks data loss or desync

		This is standard practice in Roblox games using ProfileService/ProfileStore.

		@param player Player -- The player that joined
	]=]
	onPlayerAdded = function(self, player)
		assert(typeof(player) == "Instance" and player:IsA("Player"), `expected Player instance, got {typeof(player)}`)

		-- Adapt the live Player into the narrow SessionHost surface and delegate — the lifecycle
		-- logic itself lives in _startSession so specs can drive it with a fake host + fake store.
		self:_startSession({
			userId = player.UserId,
			name = player.Name,
			isPresent = function()
				return player.Parent == Players
			end,
			kick = function(message)
				player:Kick(message)
			end,
		})
	end,

	--[=[
		The real session-start implementation behind onPlayerAdded: loads the profile, applies
		schema migrations, registers the session, and wires the session-scoped connections.
		Takes a SessionHost (not a Player) so the full join flow — load failure, migration
		refusal, left-during-load, OnSessionEnd kick — is unit-testable; onPlayerAdded adapts
		the live Player into a host. Game code must call onPlayerAdded, never this directly.
		@param host SessionHost -- The player surface: userId, name, isPresent(), kick(message)
	]=]
	_startSession = function(self, host)
		local store = self.PlayerStore
		assert(store, "PlayerStore is not initialized — init() must run before a player joins")

		local success, profile = pcall(function()
			return store:StartSessionAsync(`{host.userId}`, {
				Cancel = function()
					return not host.isPresent()
				end,
			})
		end)

		if not success then
			log:error(`Failed to load profile for {host.name}: {profile}`)
			host.kick("Profile load error - Please rejoin")
			return
		end

		if not profile then
			-- This condition should only happen when the Roblox server is shutting down
			host.kick("Profile load fail - Please rejoin")
			return
		end

		profile:AddUserId(host.userId)

		-- Read the persisted schema version BEFORE Reconcile, which would backfill it from the
		-- template and hide that this is an older profile. New profiles already carry the current
		-- version (from the template); pre-versioning profiles read as nil.
		local storedVersion = profile.Data._schemaVersion
		profile:Reconcile() -- Fill in anything missing versus template

		local migrationResult = PlayerDataMigrations.apply(profile.Data, storedVersion)
		if migrationResult ~= "ok" then
			-- Roll the WHOLE profile back to exactly what was loaded, so the final save on
			-- EndSession persists the untouched pre-migration data (real stored _schemaVersion
			-- included) instead of a Reconciled-but-unmigrated hybrid — a rejoin (or a hotfixed
			-- migration) then re-attempts against pristine data. This is what preserves the pristine
			-- NEWER data in the "too_new" case too (the Reconcile above must not be persisted). Safe
			-- because ProfileStore initializes LastSavedData as a deep copy of the loaded data at
			-- session start (ProfileStore.luau:1048), before Reconcile mutated Data in place.
			-- Restore IN PLACE (clear the table, then refill from a deep copy of LastSavedData)
			-- rather than reassigning `profile.Data` to a new table. ProfileStore tracks the profile
			-- by its `Data` table's identity; PlayerDataMigrations' successful-commit path preserves
			-- that identity for the same reason, and this failure path now matches it instead of
			-- contradicting it.
			local pristine = sift.Dictionary.copyDeep(profile.LastSavedData)
			for key in profile.Data do
				profile.Data[key] = nil
			end
			for key, value in pristine do
				profile.Data[key] = value
			end
			if migrationResult == "too_new" then
				-- Profile was written by a newer server than this one; refuse rather than migrate/stamp
				-- down (see PlayerDataMigrations "Version skew"). A rejoin lands them on a current server.
				log:error(
					`Profile for {host.name} (v{storedVersion}) is newer than this server `
						.. `(v{PlayerDataMigrations.CURRENT_VERSION}) - kicking to avoid data loss`
				)
				profile:EndSession()
				host.kick("This server is updating - please rejoin")
			else
				log:error(`Profile migration failed for {host.name} - kicking to avoid data corruption`)
				profile:EndSession()
				host.kick("Profile migration error - Please rejoin")
			end
			return
		end

		if not host.isPresent() then
			-- The player has left before the profile session started
			profile:EndSession()
			return
		end

		playerProfiles[host.userId] = profile

		-- Seed the reactive projection as soon as the profile loads, so charm-sync's ready ping
		-- delivers full initial state (and every later mutate/transaction refreshes it). No
		-- separate initial-send handshake is needed.
		ServerStore.syncFromProfile(host.userId, profile.Data)

		-- All session-scoped connections live on this janitor so they are disconnected
		-- exactly once, when the player leaves or the session ends (see _cleanupPlayer).
		local playerJanitor = Janitor.new()
		playerJanitors[host.userId] = playerJanitor

		playerJanitor:Add(
			profile.OnSessionEnd:Connect(function()
				self:_cleanupPlayer(host.userId)
				host.kick("Profile session end - Please rejoin")
			end),
			"Disconnect"
		)

		-- Detect auto-save during transactions and abort so the snapshot rollback runs (see onProfileAutoSave).
		playerJanitor:Add(
			profile.OnSave:Connect(function()
				onProfileAutoSave(host.userId)
			end),
			"Disconnect"
		)
	end,

	--[=[
		Handles when a player leaves the game and saves their profile.
		@param player Player -- The player that left
	]=]
	onPlayerRemoving = function(self, player)
		assert(typeof(player) == "Instance" and player:IsA("Player"), `expected Player instance, got {typeof(player)}`)

		local profile = playerProfiles[player.UserId]
		if profile then
			profile:EndSession()
		end
		self:_cleanupPlayer(player.UserId)
	end,

	--[=[
		Clears all session-scoped state for a user: drops the cached profile, sweeps any
		transaction lock, and destroys the player's janitor (disconnecting OnSave/OnSessionEnd).
		Safe to call repeatedly.
		@param userId number -- The user ID to clean up
	]=]
	_cleanupPlayer = function(_self, userId)
		playerProfiles[userId] = nil
		-- Belt-and-braces lock sweep: a transaction lock that somehow outlived its transaction must
		-- not outlive the session too — it would refuse this user's mutate()/transaction() until
		-- they next leave. Safe to sweep here: the locked region is fully synchronous (mutators
		-- can't yield) and the lock is released before transaction()'s only yield (the opt-in
		-- persist save), so this can never run while a lock is actually held.
		profilesInTransaction[userId] = nil
		ServerStore.remove(userId)
		local playerJanitor = playerJanitors[userId]
		if playerJanitor then
			playerJanitors[userId] = nil
			playerJanitor:Destroy()
		end
	end,

	--[=[
		Gets a read-only snapshot of a player's profile data.

		Returns a deep-frozen COPY, not the live `profile.Data`: reads are snapshots, and every
		write must go through mutate()/transaction(). Handing out the live table let any caller do
		`getCurrency(uid).gold = 1e9` directly — bypassing the transaction lock, currency caps, the
		audit log, and the ServerStore mirror. Freezing the copy turns that illegal write into a
		loud error instead of silent authoritative-state corruption. The live table is never frozen
		(mutate() writes to it); only this copy is. Single-slice reads (SliceOwner.get, and thus
		CurrencyService:getCurrency / InventoryService:getInventory) go through _getSliceShell
		below — same guarantees, but they copy only the requested slice instead of the whole profile.

		@param userId number -- The user ID to get the profile for
		@return PlayerDataTypes.PlayerProfile? -- A frozen snapshot of the player's data, or nil if not loaded
	]=]
	getProfile = function(_self, userId)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)

		local profile = playerProfiles[userId]
		if not profile then
			return nil
		end
		-- freezeProfileSnapshot returns a frozen deep COPY, so the live profile.Data stays mutable
		-- for mutate()/transaction() — the freeze applies only to the snapshot handed to the caller.
		return freezeProfileSnapshot(profile.Data)
	end,

	--[=[
		INTERNAL PLUMBING for SliceOwner.get — not for game code (the underscore marks it, like
		_startSession; game code reads via SliceOwner.get or getProfile).

		The single-slice read path: getProfile's guarantee (a deep-frozen COPY; the live table is
		never touched) at O(slice) instead of O(whole profile) cost, so a hot read like getCurrency
		no longer pays a full deep copy of every other slice (e.g. a large inventory) just to look
		at currency. Returns a shallow SHELL of the profile — `table.clone` of the top level — with
		ONLY the requested slice swapped for a frozen deep copy. The shell exists purely so
		SliceOwner's typed `read` (a field access on PlayerProfile) can re-assert the slice type on
		the way out with no written cast — the same single-boundary philosophy as
		freezeProfileSnapshot.

		CONTRACT: the caller must immediately project the swapped slice out of the shell and drop
		the shell. The shell's OTHER fields still alias the LIVE profile tables (that is what keeps
		this O(slice)), so the shell itself must never be handed to game code. SliceOwner.get is the
		one intended caller and honors this by construction (its `read` and `path` come paired from
		one registration).

		Why generics don't do this instead: the natural shape — `getSliceSnapshot<T>(userId, path,
		read: (PlayerProfile) -> T) -> T?` on this service — is rejected by the current luau-lsp for
		the same table-field-generics reason documented on `playerJanitors` above (a generic method
		on an annotated literal cannot return its own T). A function-level generic in SliceOwner
		checks cleanly, so the typed projection lives there and this stays non-generic.

		@param userId number -- The user ID to read
		@param path PlayerDataTypes.ProfilePath -- The slice's root profile key (e.g. "currency")
		@return PlayerDataTypes.PlayerProfile? -- The shell, or nil if the profile or path isn't loaded
	]=]
	_getSliceShell = function(_self, userId, path)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
		assert(type(path) == "string", `path must be a string, got {type(path)}`)

		local profile = playerProfiles[userId]
		if not profile then
			return nil
		end
		local live = profile.Data[path]
		if live == nil then
			return nil
		end
		-- Slices are tables by construction (template-seeded); the scalar branch keeps this total
		-- (a scalar needs no freeze — it is copied by value into the shell).
		local shell = table.clone(profile.Data)
		shell[path] = if type(live) == "table" then sift.Dictionary.freezeDeep(live) else live
		return shell
	end,

	--[=[
		Mutates a specific path in a player's profile data.
		Domain services should use this instead of directly modifying profile data.

		All-or-nothing per call: the slice is snapshotted before the mutator runs, and a mutator
		that yields, errors, or returns false is rolled back to the snapshot — a false return
		("no change") therefore guarantees the stored state is unchanged, even if the mutator
		wrote before aborting. Mutators MUST NOT yield (enforced, same as transaction()) and MUST
		NOT call mutate()/transaction() themselves, on any profile — every nested data-layer call
		is refused (see mutatorInFlight).

		@param userId number -- The user ID to mutate data for
		@param path PlayerDataTypes.ProfilePath -- The profile key to mutate (e.g., "currency", "inventory")
		@param mutator (data: T) -> boolean|nil -- Function that performs the mutation, returning true if data changed
		@return boolean -- True if mutation actually changed data, false otherwise
	]=]
	mutate = function(_self, userId, path, mutator)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
		assert(type(path) == "string", `path must be a string, got {type(path)}`)
		assert(type(mutator) == "function", `mutator must be a function, got {type(mutator)}`)
		ServiceController:assertSafeToCallServices("PlayerDataServiceServer")

		-- Nested-call guard (see mutatorInFlight): a mutate() issued from inside another mutator
		-- commits outside its caller's snapshots and would survive the caller's rollback — refuse it
		-- for EVERY profile, not just the locked ones the per-profile check below already covers.
		if mutatorInFlight then
			log:error("mutate() rejected: called from inside another mutator. userId:", userId, "path:", path)
			return false
		end

		-- Lock check: prevent mutation if a transaction is pending/yielding for a save
		if profilesInTransaction[userId] then
			log:warn("Cannot mutate, profile is locked by an ongoing transaction for userId:", userId)
			return false
		end

		local profile = playerProfiles[userId]
		if not profile or not profile.Data then
			log:warn("Cannot mutate, profile not loaded for userId:", userId)
			return false
		end

		-- Refuse a write to a profile whose session has ended (lock released, OnSessionEnd fired) but
		-- whose entry _cleanupPlayer hasn't yet removed. Without this, a mutate in that narrow window
		-- writes a value that will never persist AND mirrors it to the client — a server/client
		-- divergence. transaction() already guards IsActive() before commit; this matches it for mutate().
		if not profile:IsActive() then
			log:warn("Cannot mutate, profile session is no longer active for userId:", userId)
			return false
		end

		local data = profile.Data[path]
		if data == nil then
			log:warn("Cannot mutate, path not found:", path)
			return false
		end

		-- Snapshot the slice before running the mutator so EVERY rejected outcome (yield, error, or
		-- a false return) restores the pre-mutate state — the same rollback model as transaction(),
		-- for one path. Without this, a mutator that wrote and then failed would leave the live table
		-- dirty: never mirrored to ServerStore, yet persisted wholesale by ProfileStore's next
		-- auto-save — a durable write the service reported as rejected, and exactly the silent
		-- server/client divergence the sync spine exists to prevent. Slices are tables by
		-- construction (template-seeded), but the scalar branch keeps the snapshot total.
		local snapshot = if type(data) == "table" then sift.Dictionary.copyDeep(data) else data
		local function rollback()
			-- Index profile.Data at restore time (mirrors transaction's rollbackAll), so the write
			-- lands in whatever table the profile CURRENTLY holds rather than a since-detached
			-- reference captured earlier.
			profile.Data[path] = if type(snapshot) == "table" then sift.Dictionary.copyDeep(snapshot) else snapshot
		end

		-- Run the mutator in a coroutine so a yield is detectable. A yielding mutator is a contract
		-- violation: it can let a real auto-save fire and persist the half-applied write before the
		-- rollback below undoes it. Reject the whole mutation and restore the snapshot.
		-- mutatorInFlight brackets exactly the resume: mutators are synchronous, and resume() never
		-- throws, so the flag cannot leak set.
		local co = coroutine.create(mutator)
		mutatorInFlight = true
		local resumeOk, mutatorResult = coroutine.resume(co, data)
		mutatorInFlight = false
		if coroutine.status(co) ~= "dead" then
			coroutine.close(co)
			rollback()
			log:error("mutate() rejected: mutator yielded (must be synchronous). userId:", userId, "path:", path)
			return false
		end
		if not resumeOk then
			rollback()
			log:error("mutate() rejected: mutator errored:", mutatorResult, "userId:", userId, "path:", path)
			return false
		end
		if not mutatorResult then
			-- "false = no change" is now enforced, not trusted: any writes the mutator made before
			-- deciding to abort are rolled back, so the returned flag and the stored state agree.
			rollback()
			return false
		end

		-- Enforce the slice's registered invariant (e.g. currency cap / non-negative) on the RESULT,
		-- before anything is committed or mirrored. This makes the invariant a data-layer guarantee
		-- rather than a convention the service methods happen to follow: a mutator that produced an
		-- out-of-range value is rolled back exactly like a false return. Runs inside the no-yield
		-- region, so the validator (like the mutator) must be synchronous.
		local validator = PlayerDataConstants.getValidator(path)
		if validator then
			local valid, reason = validator(profile.Data[path])
			if not valid then
				rollback()
				log:error(
					"mutate() rejected: slice invariant violated. userId:",
					userId,
					"path:",
					path,
					"reason:",
					reason or "invalid"
				)
				return false
			end
		end

		log:audit(`userId={userId}`, "MUTATE_SUCCESS", `path={path}`)
		log:debug("Mutated path for userId:", userId, path)

		-- Mirror only the slice that changed into the reactive store — not the whole profile.
		-- A no-op for a path that isn't a synced slice (e.g. a future non-replicated path).
		if ServerStore.isSyncedSlice(path) then
			ServerStore.sync(path, userId, profile.Data)
		end
		return true
	end,

	--[=[
		Executes multiple mutations atomically across one or more users.
		If any operation returns false or crashes, all changes are rolled back.

		PREFER the typed op builders over raw operation tables: each slice-owning service exposes one
		(`CurrencyService:currencyOp`, `InventoryService:inventoryOp`, via SliceOwner's `op`) whose
		mutator param is fully typed to the slice — no inline annotations needed. Raw tables (below)
		remain supported; type your mutator parameters inline for intellisense:
		Supports single-user and multi-user (e.g., trades) transactions:
		```lua
		-- Single user example:
		local success = PlayerDataService:transaction({
			{ userId = playerId, path = "currency", mutator = function(c) c.gold = c.gold - 100; return true end },
			{ userId = playerId, path = "inventory", mutator = function(i) table.insert(i, item); return true end },
		})

		-- Trade example (two users):
		local success = PlayerDataService:transaction({
			{ userId = sellerUserId, path = "inventory", mutator = function(inv) removeItem(inv, sword); return true end },
			{ userId = sellerUserId, path = "currency", mutator = function(c) c.gold = c.gold + 500; return true end },
			{ userId = buyerUserId, path = "inventory", mutator = function(inv) addItem(inv, sword); return true end },
			{ userId = buyerUserId, path = "currency", mutator = function(c) c.gold = c.gold - 500; return true end },
		})
		```

		Durability: by default a transaction commits IN MEMORY and lets the normal ProfileStore
		auto-save persist it (same model as mutate()) — no forced DataStore write, so routine
		transactions cost only two in-memory table copies. Pass `{ persist = true }` for economy-
		critical writes (trades) to force an immediate save with bounded retries and confirm durability
		via the returned `persisted` / `failedUserIds`.

		Constraints:
		- Mutators MUST NOT yield — this is ENFORCED. Each mutator runs in a coroutine; a mutator that
		  yields is rejected and the whole transaction rolls back. (A synchronous apply loop is what
		  lets the rollback point be a cheap in-memory snapshot instead of a forced pre-save: with no
		  yield, no auto-save can interleave and swap a profile's Data table out mid-transaction.)
		- Do not call transaction()/mutate() from inside a mutator, on ANY profile — every nested
		  data-layer call is refused (see mutatorInFlight). A nested write on an affected profile would
		  corrupt the lock state (the re-entry guard also covers that), and one on an UNAFFECTED profile
		  would commit outside this transaction's snapshots and survive its rollback — breaking
		  all-or-nothing. Compose multi-profile writes as sibling ops of one transaction instead.

		@param operations {TransactionOperation} -- Array of operations to execute
		@param options TransactionOptions? -- { persist = true } to force an immediate durable save
		@return boolean -- committed: true only if every mutator applied and the transaction committed in memory
		@return TransactionResult -- persisted/failedUserIds; see TransactionResult. A default transaction
		  reports persisted=false (committed in memory, auto-save will write it); callers of economy-
		  critical trades should pass `{ persist = true }` and check `result.persisted`.
	]=]
	transaction = function(_self, operations, options)
		assert(type(operations) == "table", `operations must be a table, got {type(operations)}`)
		ServiceController:assertSafeToCallServices("PlayerDataServiceServer")

		local function failResult(): TransactionResult
			return { committed = false, persisted = false, failedUserIds = {} }
		end

		-- Nested-call guard (see mutatorInFlight): a transaction() launched from inside a mutator
		-- would commit its profiles outside the outer call's snapshots — even DISJOINT profiles the
		-- per-profile re-entry guard below can't see — so its writes would survive the outer rollback.
		if mutatorInFlight then
			log:error("transaction() rejected: called from inside a mutator")
			return false, failResult()
		end

		-- Phase 1: validate that every referenced profile is loaded and every referenced path
		-- exists. This pass has NO side effects, so bailing here can never leave an earlier
		-- profile locked.
		local affectedProfiles: { [number]: ProfileStoreTyped.Profile } = {}
		local affectedUserCount = 0
		for _, op in operations do
			-- Validate the FULL op shape here, in side-effect-free Phase 1 (mirroring mutate()'s
			-- asserts). These must never be deferred to the apply loop: a throw inside the locked
			-- region would skip clearTransactionFlags and leave every affected profile permanently
			-- locked (refusing all future mutate/transaction calls for those users).
			assert(type(op.userId) == "number", `each operation must have a userId, got {type(op.userId)}`)
			assert(type(op.path) == "string", `each operation must have a string path, got {type(op.path)}`)
			assert(
				type(op.mutator) == "function",
				`each operation must have a function mutator, got {type(op.mutator)}`
			)
			if not affectedProfiles[op.userId] then
				-- Re-entry guard: a profile already inside a transaction (e.g. a mutator that calls
				-- transaction() again on an overlapping profile) must not be re-locked — the nested
				-- commit would clear the outer transaction's flags and corrupt its lock state.
				if profilesInTransaction[op.userId] then
					log:warn("Cannot execute transaction, profile already in a transaction for userId:", op.userId)
					return false, failResult()
				end
				local profile = playerProfiles[op.userId]
				if not profile or not profile.Data then
					log:warn("Cannot execute transaction, profile not loaded for userId:", op.userId)
					return false, failResult()
				end
				affectedProfiles[op.userId] = profile
				affectedUserCount += 1
			end
			-- Mirror mutate()'s existence guard. A nil path is a caller bug (slices are pre-seeded by
			-- the template), and the rollback snapshot below cannot represent "path absent" — a
			-- mutator that CREATED the path would survive a rollback, breaking all-or-nothing.
			-- Refusing up front closes that atomicity gap.
			if affectedProfiles[op.userId].Data[op.path] == nil then
				log:warn("Cannot execute transaction, path not found:", op.path, "for userId:", op.userId)
				return false, failResult()
			end
		end

		-- Phase 2: lock each affected profile and snapshot its touched paths in memory as the rollback
		-- point. Mutators cannot yield (enforced in the apply loop below), so nothing interleaves
		-- between here and commit — an in-memory deep copy is a complete rollback anchor, with no
		-- DataStore write and no multi-second wait. Durable persistence is opt-in (see the commit phase).
		--
		-- Each snapshot is wrapped in `{ value = ... }` for two reasons, both scalar-path safety
		-- (mirroring mutate()'s scalar branch): sift's copyDeep THROWS on a non-table, and this loop
		-- runs with the locks above already set — an unguarded throw here would skip
		-- clearTransactionFlags and leave every affected profile locked until the player leaves. The
		-- wrapper also keeps "already snapshotted" distinguishable from "snapshot is the scalar false"
		-- (a bare-value map couldn't, and re-snapshotting mid-apply would corrupt the rollback anchor).
		local snapshots: { [number]: { [string]: { value: any } } } = {}
		for userId in affectedProfiles do
			profilesInTransaction[userId] = { aborted = false }
			snapshots[userId] = {}
		end
		for _, op in operations do
			local perPath = snapshots[op.userId]
			if perPath[op.path] == nil then
				-- Phase 1 guarantees the path exists, so every touched path gets a snapshot entry
				-- and rollbackAll can always restore it.
				local current = affectedProfiles[op.userId].Data[op.path]
				perPath[op.path] = {
					value = if type(current) == "table" then sift.Dictionary.copyDeep(current) else current,
				}
			end
		end

		-- Restore every touched path from its pre-transaction snapshot, discarding in-place mutations.
		local function rollbackAll(reason: string)
			for userId, perPath in snapshots do
				local profileData = affectedProfiles[userId].Data
				for path, snap in perPath do
					profileData[path] = if type(snap.value) == "table"
						then sift.Dictionary.copyDeep(snap.value)
						else snap.value
				end
			end
			log:warn("Transaction rolled back:", reason)
		end

		-- Helper function to clear transaction flags
		local function clearTransactionFlags()
			for odUserId in affectedProfiles do
				profilesInTransaction[odUserId] = nil
			end
		end

		-- Tracks which (userId, path) pairs actually changed data, so the post-commit mirror
		-- below re-syncs only those slices instead of every affected profile in full.
		local touchedSlices: { [number]: { [string]: boolean } } = {}

		-- Execute all operations with error protection
		for i, op in operations do
			-- Check if auto-save fired during transaction
			local txnState = profilesInTransaction[op.userId]
			if txnState and txnState.aborted then
				rollbackAll("auto-save detected mid-transaction for userId: " .. op.userId)
				clearTransactionFlags()
				return false, failResult()
			end

			local profile = affectedProfiles[op.userId]
			local data = profile.Data[op.path]

			-- Coroutine (not pcall) so a yield is caught actively — pcall would suspend the whole
			-- transaction on a yielding mutator instead of rejecting it. mutatorInFlight brackets
			-- exactly the resume (see mutate()); resume() never throws, so the flag cannot leak set.
			local co = coroutine.create(op.mutator)
			mutatorInFlight = true
			local resumeOk, mutatorResult = coroutine.resume(co, data)
			mutatorInFlight = false
			if coroutine.status(co) ~= "dead" then
				coroutine.close(co)
				log:error("Transaction mutator yielded at op", i, "(must be synchronous)")
				rollbackAll("mutator yielded at op " .. i)
				clearTransactionFlags()
				return false, failResult()
			end
			if not resumeOk then
				log:error("Transaction mutator crashed at op", i, "error:", mutatorResult)
				rollbackAll("mutator crash at op " .. i)
				clearTransactionFlags()
				return false, failResult()
			end

			-- Handle mutator returning false (intentional abort)
			if not mutatorResult then
				rollbackAll("mutator returned false at op " .. i)
				clearTransactionFlags()
				return false, failResult()
			end

			-- Defensive: if `aborted` somehow flipped during this mutator (see onProfileAutoSave —
			-- an impossible-in-production state that would indicate a yield leaked into the locked
			-- region), catch it here, before recording the slice as touched, so we bail and roll
			-- back rather than committing a half-applied op.
			local postState = profilesInTransaction[op.userId]
			if postState and postState.aborted then
				rollbackAll("auto-save detected during mutator for userId: " .. op.userId)
				clearTransactionFlags()
				return false, failResult()
			end

			-- Enforce the slice's registered invariant on the RESULT of this op (see mutate()). A raw
			-- transaction op whose mutator bypassed the owning service's methods — e.g. a trade pushing
			-- currency past its cap or negative — is caught here and rolls the WHOLE transaction back,
			-- so the cap holds no matter how the op was built. Runs in the no-yield locked region.
			local validator = PlayerDataConstants.getValidator(op.path)
			if validator then
				local valid, reason = validator(profile.Data[op.path])
				if not valid then
					rollbackAll(`slice invariant violated at op {i} (path {op.path}): {reason or "invalid"}`)
					clearTransactionFlags()
					return false, failResult()
				end
			end

			local userSlices = touchedSlices[op.userId]
			if not userSlices then
				userSlices = {}
				touchedSlices[op.userId] = userSlices
			end
			userSlices[op.path] = true
		end

		-- Final check for auto-save before committing
		for odUserId in affectedProfiles do
			local txnState = profilesInTransaction[odUserId]
			if txnState and txnState.aborted then
				rollbackAll("auto-save detected before commit for userId: " .. odUserId)
				clearTransactionFlags()
				return false, failResult()
			end
		end

		-- Every affected profile must still be active to commit. A profile that is inactive (its session
		-- ended) can't be persisted, so committing would apply the active participants and silently drop
		-- the inactive one — a non-atomic outcome (e.g. a trade where only one side lands). Treat it as a
		-- full failure and roll the in-memory state back rather than committing an asymmetric result.
		for userId, profile in affectedProfiles do
			if not profile:IsActive() then
				rollbackAll("profile went inactive before commit for userId: " .. userId)
				clearTransactionFlags()
				return false, failResult()
			end
		end

		-- In-memory commit is done; release the locks.
		clearTransactionFlags()

		-- Durability is opt-in. A default transaction commits in memory and rides the normal auto-save
		-- cadence (exactly like mutate()); options.persist forces an immediate save with bounded
		-- retries so economy-critical callers can confirm durability via the returned persisted /
		-- failedUserIds. Yielding here is safe — the transaction is already committed in memory and its
		-- locks are released, so an auto-save that fires during the backoff simply persists it.
		local persist = options ~= nil and options.persist == true
		local failedUserIds: { number } = {}
		if persist then
			local confirmTimeout = persistConfirmTimeoutOverride or TRANSACTION_COMMIT_CONFIRM_TIMEOUT_SECONDS
			for userId, profile in affectedProfiles do
				-- Durability is confirmed by OnAfterSave, not by Save() returning: Save() is
				-- fire-and-forget (see TRANSACTION_COMMIT_CONFIRM_TIMEOUT_SECONDS above), and
				-- OnAfterSave fires only after the UpdateAsync lands while the session still owns the
				-- profile. Any post-commit OnAfterSave confirms our writes — the commit happened before
				-- this connection, so a save completing after it captured the committed Data. Known
				-- narrow race: an auto-save whose UpdateAsync was already in flight ACROSS the commit
				-- can complete here having captured pre-commit data; the commit is still in memory and
				-- the next auto-save persists it, so the flag can be early, never wrong-direction-durable.
				local confirmed = false
				local connection = profile.OnAfterSave:Connect(function()
					confirmed = true
				end)
				local saved = false
				for attempt = 1, TRANSACTION_COMMIT_SAVE_ATTEMPTS do
					if not profile:IsActive() then
						break
					end
					local saveSuccess, saveErr = pcall(function()
						profile:Save()
					end)
					if saveSuccess then
						local deadline = os.clock() + confirmTimeout
						while not confirmed and os.clock() < deadline and profile:IsActive() do
							task.wait()
						end
						if confirmed then
							saved = true
							break
						end
						log:error(
							"Transaction save dispatched but not confirmed (no OnAfterSave) for userId:",
							userId,
							"attempt:",
							attempt
						)
					else
						log:error(
							"Failed to save transaction for userId:",
							userId,
							"attempt:",
							attempt,
							"error:",
							saveErr
						)
					end
					if attempt < TRANSACTION_COMMIT_SAVE_ATTEMPTS then
						task.wait(attempt * TRANSACTION_COMMIT_RETRY_BASE_SECONDS)
					end
				end
				connection:Disconnect()
				if not saved then
					table.insert(failedUserIds, userId)
				end
			end
		end

		-- Mirror only the slices that actually changed, not every affected profile in full — same
		-- rationale as mutate(). A no-op for a path that isn't a synced slice.
		for userId, paths in touchedSlices do
			-- The persist loop above yields (Save + backoff) with the locks already released, so a
			-- player can leave during it — _cleanupPlayer then removes them from ServerStore. Skip
			-- re-mirroring a departed profile: affectedProfiles still holds the ref, but syncing it
			-- would re-insert a slice for a gone session that nothing ever removes again (a zombie
			-- atom entry). A default (non-persist) transaction never yields here, so this only
			-- guards the persist path.
			if playerProfiles[userId] == nil then
				continue
			end
			local profile = affectedProfiles[userId]
			for path in paths do
				if ServerStore.isSyncedSlice(path) then
					ServerStore.sync(path, userId, profile.Data)
				end
			end
		end

		-- Audit the commit per affected user (mirroring mutate()'s MUTATE_SUCCESS line): transactions
		-- are THE economy-critical path (trades), so a committed one must land in the audit trail,
		-- not just the debug channel.
		for userId, paths in touchedSlices do
			local pathNames = {}
			for path in paths do
				table.insert(pathNames, path)
			end
			table.sort(pathNames)
			log:audit(
				`userId={userId}`,
				"TRANSACTION_COMMIT",
				`paths={table.concat(pathNames, ",")}`,
				`persist={persist}`
			)
		end
		log:debug("Transaction committed, #ops:", #operations, "#users:", affectedUserCount, "persist:", persist)
		return true,
			{
				committed = true,
				-- Durable this call only when a persist=true save actually ran and succeeded for every
				-- affected profile. The `affectedUserCount > 0` guard keeps an empty transaction from
				-- vacuously reporting persisted=true (no save happened). A default transaction is
				-- committed in memory (persisted=false); the next auto-save writes it.
				persisted = persist and affectedUserCount > 0 and #failedUserIds == 0,
				failedUserIds = failedUserIds,
			}
	end,

	--[=[
		Cleans up event listeners and ends all active sessions.
		@param self PlayerDataServiceServer -- The service instance
	]=]
	stop = function(self)
		-- End all active profile sessions
		for userId, profile in playerProfiles do
			profile:EndSession()
			playerProfiles[userId] = nil
		end

		-- Sweep all transaction locks (same rationale as _cleanupPlayer): no session survives
		-- stop(), so no lock may either.
		table.clear(profilesInTransaction)

		-- Destroy any remaining per-player janitors. Index-then-narrow (rather than calling
		-- :Destroy() on the loop variable directly) so the value is the narrowed, concrete
		-- Janitor type — Janitor's generic methods otherwise trip luau-lsp's invariant
		-- self-check on a value read straight out of the iteration. Mirrors _cleanupPlayer.
		for userId in playerJanitors do
			local playerJanitor = playerJanitors[userId]
			if playerJanitor then
				playerJanitors[userId] = nil
				playerJanitor:Destroy()
			end
		end

		self.PlayerStore = nil
		janitor:Cleanup()
		log:debug("Service stopped, connections cleaned up")
	end,

	--[=[
		Returns session-level diagnostics for the debugger — deliberately NOT slice values. Slice
		data is visible through the reactive atoms (ServerStore mirrors this service's writes and the
		client State panel renders them); repeating it here would be redundant. What has no other
		window is the session machinery itself: which profiles are loaded and active, which are
		locked mid-transaction, and whether the store is mocked (Studio) — the instant answer to
		"why isn't my data persisting".
		@return { [string]: any } -- Service state
	]=]
	getState = function(_self)
		local sessions = {}
		for userId, profile in playerProfiles do
			sessions[tostring(userId)] = {
				hasData = profile.Data ~= nil,
				active = profile:IsActive(),
				inTransaction = profilesInTransaction[userId] ~= nil,
			}
		end
		return {
			usingMockStore = usingMockStore,
			sessions = sessions,
		}
	end,

	--[=[
		TEST SEAM — not for use in game code.
		Seeds (or clears, when `profile` is nil) the internal profile registry so spec
		files can exercise mutate()/transaction() against fake, ProfileStore-shaped
		profiles without a live session. Game code obtains profiles via the player
		lifecycle (onPlayerAdded), never through this method.
		@param userId number -- The user ID
		@param profile ProfileStoreTyped.Profile? -- A profile-like object, or nil to clear the entry
	]=]
	_setProfileForTesting = function(_self, userId, profile)
		local existing = testSeamSaveConnections[userId]
		if existing then
			existing:Disconnect()
			testSeamSaveConnections[userId] = nil
		end
		if profile then
			playerProfiles[userId] = profile
			-- Wire the SAME auto-save abort handler onPlayerAdded wires for live sessions, so a
			-- spec that fires the fake profile's OnSave mid-transaction exercises the real abort
			-- machinery rather than a spec-local imitation of it.
			testSeamSaveConnections[userId] = profile.OnSave:Connect(function()
				onProfileAutoSave(userId)
			end)
		else
			playerProfiles[userId] = nil
		end
	end,

	--[=[
		TEST SEAM — not for use in game code.
		Overrides how long a persist=true save waits for OnAfterSave confirmation, so specs that
		exercise the dispatched-but-never-confirmed path don't stall on the production timeout.
		Pass nil to restore the default.
		@param seconds number? -- Override in seconds, or nil to reset
	]=]
	_setPersistConfirmTimeoutForTesting = function(_self, seconds)
		persistConfirmTimeoutOverride = seconds
	end,
}

return PlayerDataServiceServer
