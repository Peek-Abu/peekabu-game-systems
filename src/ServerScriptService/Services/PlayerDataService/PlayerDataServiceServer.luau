--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local PlayerDataEvents = require(ReplicatedStorage.Shared.Events.PlayerDataEvents)
local ProfileStoreTyped = require(ServerScriptService.Modules.ProfileStoreTyped)
local PlayerDataMigrations = require(ServerScriptService.Modules.PlayerDataMigrations)
local RequestHandler = require(ServerScriptService.Modules.RequestHandler)
local sift = require(ReplicatedStorage.Packages.sift)
local log = Logger.new("PlayerDataServiceServer")

local janitor = Janitor.new()

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

-- Tracks profiles currently in a transaction for auto-save abort detection.
-- `isPreSaving` is true only during the Phase-2 forced save that establishes the
-- LastSavedData rollback point; the OnSave handler ignores that expected save so it
-- isn't mistaken for a mid-transaction auto-save.
local profilesInTransaction: { [number]: { aborted: boolean, isPreSaving: boolean? } } = {}

-- Initial-sync handshake state. The client fires PlayerReady once its data listeners are
-- set up; the initial profile is sent only when BOTH the profile is loaded and the client
-- is ready, and exactly once per session. Replaces a fixed task.wait() timing guess.
local clientReady: { [number]: boolean } = {}
local initialProfileSent: { [number]: boolean } = {}

export type TransactionOperation = {
	userId: number,
	path: PlayerDataTypes.ProfilePath,
	mutator: (data: any) -> boolean, -- Return false to abort transaction
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
	onPlayerRemoving: (self: PlayerDataServiceServer, player: Player) -> (),
	_cleanupPlayer: (self: PlayerDataServiceServer, userId: number) -> (),
	getProfile: (self: PlayerDataServiceServer, userId: number) -> PlayerDataTypes.PlayerProfile?,
	mutate: <T>(
		self: PlayerDataServiceServer,
		userId: number,
		path: PlayerDataTypes.ProfilePath,
		mutator: (data: T) -> boolean?
	) -> boolean,
	transaction: (self: PlayerDataServiceServer, operations: { TransactionOperation }) -> boolean,
	_trySendInitialProfile: (self: PlayerDataServiceServer, userId: number) -> (),
	broadcastProfile: (self: PlayerDataServiceServer, userId: number) -> (),
	stop: (self: PlayerDataServiceServer) -> (),
	getState: (self: PlayerDataServiceServer) -> { [string]: any },
	_setProfileForTesting: (self: PlayerDataServiceServer, userId: number, profile: ProfileStoreTyped.Profile?) -> (),
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

		self.PlayerStore = ProfileStoreTyped.new(configs.storeName, configs.template, configs.useMock)
		janitor:Add(
			Observers.observePlayer(function(player)
				self:onPlayerAdded(player)
				return function()
					self:onPlayerRemoving(player)
				end
			end),
			true
		)

		-- The client signals readiness for its initial profile sync via PlayerReady. Routed through
		-- RequestHandler for per-player rate limiting (the handler is idempotent, so this just caps
		-- packet spam) and error isolation. ByteNet always passes the firing Player on the server.
		janitor:Add(
			PlayerDataEvents.packets.PlayerReady.listen(RequestHandler.wrap({
				name = "PlayerReady",
				rateLimit = { maxRequests = 5, windowSeconds = 10 },
				handler = function(_data, player: Player)
					clientReady[player.UserId] = true
					self:_trySendInitialProfile(player.UserId)
				end,
			})),
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

		local store = self.PlayerStore
		assert(store, "PlayerStore is not initialized — init() must run before a player joins")

		local success, profile = pcall(function()
			return store:StartSessionAsync(`{player.UserId}`, {
				Cancel = function()
					return player.Parent ~= Players
				end,
			})
		end)

		if not success then
			log:error(`Failed to load profile for {player.Name}: {profile}`)
			player:Kick("Profile load error - Please rejoin")
			return
		end

		if not profile then
			-- This condition should only happen when the Roblox server is shutting down
			player:Kick("Profile load fail - Please rejoin")
			return
		end

		profile:AddUserId(player.UserId)

		-- Read the persisted schema version BEFORE Reconcile, which would backfill it from the
		-- template and hide that this is an older profile. New profiles already carry the current
		-- version (from the template); pre-versioning profiles read as nil.
		local storedVersion = profile.Data._schemaVersion
		profile:Reconcile() -- Fill in anything missing versus template

		if not PlayerDataMigrations.apply(profile.Data, storedVersion) then
			-- Reconcile above may have backfilled _schemaVersion to the current version. Restore the
			-- real stored version before the session ends so the persisted profile isn't falsely
			-- marked as migrated — a rejoin (or a hotfixed migration) must re-attempt it.
			profile.Data._schemaVersion = storedVersion
			log:error(`Profile migration failed for {player.Name} - kicking to avoid data corruption`)
			profile:EndSession()
			player:Kick("Profile migration error - Please rejoin")
			return
		end

		if player.Parent ~= Players then
			-- The player has left before the profile session started
			profile:EndSession()
			return
		end

		playerProfiles[player.UserId] = profile

		-- All session-scoped connections live on this janitor so they are disconnected
		-- exactly once, when the player leaves or the session ends (see _cleanupPlayer).
		local playerJanitor = Janitor.new()
		playerJanitors[player.UserId] = playerJanitor

		playerJanitor:Add(
			profile.OnSessionEnd:Connect(function()
				self:_cleanupPlayer(player.UserId)
				player:Kick("Profile session end - Please rejoin")
			end),
			"Disconnect"
		)

		-- Detect auto-save during transactions and restore from LastSavedData
		playerJanitor:Add(
			profile.OnSave:Connect(function()
				local txnState = profilesInTransaction[player.UserId]
				if txnState and not txnState.aborted and not txnState.isPreSaving then
					txnState.aborted = true
					-- Restore entire Profile.Data from LastSavedData before save completes. ProfileStore
					-- reads `.Data` fresh at save time, so reassigning a deep copy is safe (and any-free).
					profile.Data = sift.Dictionary.copyDeep(profile.LastSavedData)
					log:warn("Auto-save during transaction - restored LastSavedData for userId:", player.UserId)
				end
			end),
			"Disconnect"
		)

		-- Send the initial profile sync. Rather than guessing client-listener timing with a
		-- fixed wait, we rely on the client's PlayerReady signal: if it already arrived this
		-- sends now, otherwise the PlayerReady listener sends it once it does. Either ordering
		-- delivers exactly one initial sync.
		self:_trySendInitialProfile(player.UserId)
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
		Clears all session-scoped state for a user: drops the cached profile and destroys
		the player's janitor (disconnecting OnSave/OnSessionEnd). Safe to call repeatedly.
		@param userId number -- The user ID to clean up
	]=]
	_cleanupPlayer = function(_self, userId)
		playerProfiles[userId] = nil
		clientReady[userId] = nil
		initialProfileSent[userId] = nil
		local playerJanitor = playerJanitors[userId]
		if playerJanitor then
			playerJanitors[userId] = nil
			playerJanitor:Destroy()
		end
	end,

	--[=[
		Gets a player's profile data.

		@param userId number -- The user ID to get the profile for
		@return PlayerDataTypes.PlayerProfile? -- The player's profile data or nil if not loaded
	]=]
	getProfile = function(_self, userId)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)

		local profile = playerProfiles[userId]
		return profile and profile.Data
	end,

	--[=[
		Mutates a specific path in a player's profile data.
		Domain services should use this instead of directly modifying profile data.

		@param userId number -- The user ID to mutate data for
		@param path PlayerDataTypes.ProfilePath -- The profile key to mutate (e.g., "currency", "inventory")
		@param mutator (data: T) -> boolean|nil -- Function that performs the mutation, returning true if data changed
		@return boolean -- True if mutation actually changed data, false otherwise
	]=]
	mutate = function(_self, userId, path, mutator)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
		assert(type(path) == "string", `path must be a string, got {type(path)}`)
		assert(type(mutator) == "function", `mutator must be a function, got {type(mutator)}`)

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

		local data = (profile.Data :: any)[path]
		if data == nil then
			log:warn("Cannot mutate, path not found:", path)
			return false
		end

		local success = mutator(data)
		if not success then
			return false
		end

		log:audit(`userId={userId}`, "MUTATE_SUCCESS", `path={path}`)
		log:debug("Mutated path for userId:", userId, path)
		return true
	end,

	--[=[
		Executes multiple mutations atomically across one or more users.
		If any operation returns false or crashes, all changes are rolled back.

		Type your mutator parameters inline for full intellisense:
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

		@param operations {TransactionOperation} -- Array of operations to execute
		@return boolean -- True if all operations succeeded, false if rolled back
	]=]
	transaction = function(_self, operations)
		assert(type(operations) == "table", `operations must be a table, got {type(operations)}`)

		-- Phase 1: validate that every referenced profile is loaded. This pass has NO side
		-- effects, so bailing here can never leave an earlier profile locked.
		local affectedProfiles: { [number]: ProfileStoreTyped.Profile } = {}
		local affectedUserCount = 0
		for _, op in operations do
			assert(type(op.userId) == "number", `each operation must have a userId, got {type(op.userId)}`)
			if not affectedProfiles[op.userId] then
				local profile = playerProfiles[op.userId]
				if not profile or not profile.Data then
					log:warn("Cannot execute transaction, profile not loaded for userId:", op.userId)
					return false
				end
				affectedProfiles[op.userId] = profile
				affectedUserCount += 1
			end
		end

		-- Phase 2: lock each affected profile and force a save to establish the
		-- LastSavedData rollback point before we yield.
		local savesPending = 0
		-- Pre-save OnAfterSave listeners, tracked so we can release any that never fire
		-- (e.g. on a save timeout below) instead of leaking a connection per transaction.
		local presaveConns: { ProfileStoreTyped.Connection } = {}
		for userId, profile in affectedProfiles do
			-- Lock the profile BEFORE yielding for Save()
			profilesInTransaction[userId] = { aborted = false, isPreSaving = true }

			-- Force save to ensure LastSavedData is current
			if profile:IsActive() then
				savesPending += 1
				local conn
				conn = profile.OnAfterSave:Connect(function()
					savesPending -= 1
					local txnState = profilesInTransaction[userId]
					if txnState then
						txnState.isPreSaving = false
					end
					conn:Disconnect()
				end)
				table.insert(presaveConns, conn)

				local saveSuccess, saveErr = pcall(function()
					profile:Save()
				end)
				if not saveSuccess then
					log:error("Failed to force save during transaction pre-save for userId:", userId, "error:", saveErr)
					savesPending -= 1
					conn:Disconnect()
				end
			end
		end

		-- Wait for all saves to complete (with timeout)
		local startTime = os.clock()
		while savesPending > 0 and os.clock() - startTime < 10 do
			task.wait()
		end

		-- Release pre-save listeners. On the happy path each has already self-disconnected
		-- (Disconnect is idempotent); on a timeout this cleans up the ones that never fired.
		for _, conn in presaveConns do
			conn:Disconnect()
		end

		-- Helper function to rollback from LastSavedData
		local function rollbackAll(reason: string)
			for _, profile in affectedProfiles do
				profile.Data = sift.Dictionary.copyDeep(profile.LastSavedData)
			end
			log:warn("Transaction rolled back:", reason)
		end

		-- Helper function to clear transaction flags
		local function clearTransactionFlags()
			for odUserId in affectedProfiles do
				profilesInTransaction[odUserId] = nil
			end
		end

		if savesPending > 0 then
			log:warn("Transaction aborted: pre-save timeout")
			clearTransactionFlags()
			return false
		end

		-- Execute all operations with error protection
		for i, op in operations do
			-- Check if auto-save fired during transaction
			local txnState = profilesInTransaction[op.userId]
			if txnState and txnState.aborted then
				rollbackAll("auto-save detected mid-transaction for userId: " .. op.userId)
				clearTransactionFlags()
				return false
			end

			local profile = affectedProfiles[op.userId]
			local data = (profile.Data :: any)[op.path]

			-- Wrap mutator in pcall to catch runtime errors
			local pcallSuccess, mutatorResult = pcall(function()
				return op.mutator(data)
			end)

			if not pcallSuccess then
				log:error("Transaction mutator crashed at op", i, "error:", mutatorResult)
				rollbackAll("mutator crash at op " .. i)
				clearTransactionFlags()
				return false
			end

			-- Handle mutator returning false (intentional abort)
			if not mutatorResult then
				rollbackAll("mutator returned false at op " .. i)
				clearTransactionFlags()
				return false
			end
		end

		-- Final check for auto-save before committing
		for odUserId in affectedProfiles do
			local txnState = profilesInTransaction[odUserId]
			if txnState and txnState.aborted then
				rollbackAll("auto-save detected before commit for userId: " .. odUserId)
				clearTransactionFlags()
				return false
			end
		end

		-- Clear transaction flags before forcing save
		clearTransactionFlags()

		-- Force save all affected profiles to persist the transaction immediately
		for userId, profile in affectedProfiles do
			if profile:IsActive() then
				local saveSuccess, saveErr = pcall(function()
					profile:Save()
				end)
				if not saveSuccess then
					log:error("Failed to save transaction for userId:", userId, "error:", saveErr)
					-- Transaction already committed to memory, save will retry on auto-save
				end
			end
		end

		log:debug("Transaction completed and saved, #ops:", #operations, "#users:", affectedUserCount)
		return true
	end,

	--[=[
		Sends the initial profile to a player exactly once, and only when BOTH the profile is
		loaded AND the client has signaled readiness (PlayerReady). Safe to call from either the
		profile-loaded path (onPlayerAdded) or the client-ready path (the PlayerReady listener) —
		whichever happens last performs the send. Idempotent.
		@param userId number -- The user ID
	]=]
	_trySendInitialProfile = function(self, userId)
		if initialProfileSent[userId] then
			return
		end
		if not clientReady[userId] or not playerProfiles[userId] then
			return
		end
		initialProfileSent[userId] = true
		self:broadcastProfile(userId)
	end,

	--[=[
		Broadcasts the current profile data to the specified player.
		Only fires initially to sync to client.
		@param userId number -- The user ID to broadcast the profile for
	]=]
	broadcastProfile = function(_self, userId)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)

		local profile = playerProfiles[userId]
		if profile then
			local player = Players:GetPlayerByUserId(userId)
			if not player then
				return
			end
			PlayerDataEvents.packets.PlayerProfileUpdate.sendTo({
				userId = userId,
				currency = profile.Data.currency,
				inventory = profile.Data.inventory,
			}, player)
		end
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
		Returns the current state of the service for debugging.
		@return { [string]: any } -- Service state
	]=]
	getState = function(_self)
		local loadedProfiles = {}
		for userId, profile in playerProfiles do
			loadedProfiles[tostring(userId)] = {
				hasData = profile.Data ~= nil,
				currency = profile.Data and profile.Data.currency or nil,
				inventoryCount = profile.Data and #profile.Data.inventory or 0,
			}
		end
		return {
			profiles = loadedProfiles,
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
		if profile then
			playerProfiles[userId] = profile
		else
			playerProfiles[userId] = nil
		end
	end,
}

return PlayerDataServiceServer
