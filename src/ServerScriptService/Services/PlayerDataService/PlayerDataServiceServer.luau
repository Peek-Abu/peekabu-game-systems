--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local PlayerDataEvents = require(ReplicatedStorage.Shared.Events.PlayerDataEvents)
local PlayerDataConstants = require(ServerScriptService.Modules.Constants.PlayerDataConstants)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore) -- adjust path!
local sift = require(ReplicatedStorage.Packages.sift)
local log = Logger.new("PlayerDataServiceServer")

local PlayerDataServiceServer = {}

local janitor = Janitor.new()

local playerProfiles: { [number]: ProfileStore.Profile<PlayerDataTypes.PlayerProfile> } = {}

-- Tracks profiles currently in a transaction for auto-save abort detection
local profilesInTransaction: { [number]: { aborted: boolean } } = {}

--[=[
	Initializes the PlayerDataServiceServer and sets up event connections.
	@param self PlayerDataServiceServer -- The service instance
]=]
function PlayerDataServiceServer.init(self: PlayerDataServiceServer, configs: PlayerDataTypes.PlayerDataServiceConfigs)
	-- Profile template is now dynamically assembled by domain services via `PlayerDataConstants.registerProfilePath`
	-- before this init method is called.
	log:debug("Initialized with template:", configs.template)

	self.PlayerStore = ProfileStore.New(configs.storeName, configs.template)
	if configs.useMock then
		self.PlayerStore = self.PlayerStore.Mock
	end
	janitor:Add(Players.PlayerAdded:Connect(function(player)
		self:onPlayerAdded(player)
	end))
	janitor:Add(Players.PlayerRemoving:Connect(function(player)
		self:onPlayerRemoving(player)
	end))
	-- In case Players have joined the server earlier than this script ran:
	for _, player in Players:GetPlayers() do
		task.spawn(function(playerJoined)
			self:onPlayerAdded(playerJoined)
		end, player)
	end
end

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
function PlayerDataServiceServer:onPlayerAdded(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), `expected Player instance, got {typeof(player)}`)

	local success, profile = pcall(function()
		return self.PlayerStore:StartSessionAsync(`{player.UserId}`, {
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

	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile() -- Fill in anything missing versus template

		profile.OnSessionEnd:Connect(function()
			playerProfiles[player.UserId] = nil
			player:Kick("Profile session end - Please rejoin")
		end)

		if player.Parent == Players then
			playerProfiles[player.UserId] = profile

			-- Detect auto-save during transactions and restore from LastSavedData
			janitor:Add(profile.OnSave:Connect(function()
				local txnState = profilesInTransaction[player.UserId]
				if txnState and not txnState.aborted and not txnState.isPreSaving then
					txnState.aborted = true
					-- Restore entire Profile.Data from LastSavedData before save completes
					for key, value in sift.Dictionary.copyDeep(profile.LastSavedData) do
						profile.Data[key] = value
					end
					log:warn("Auto-save during transaction - restored LastSavedData for userId:", player.UserId)
				end
			end), "Disconnect")

			self:broadcastProfile(player.UserId)
		else
			-- The player has left before the profile session started
			profile:EndSession()
		end
	else
		-- This condition should only happen when the Roblox server is shutting down
		player:Kick("Profile load fail - Please rejoin")
	end
end

--[=[
	Handles when a player leaves the game and saves their profile.
	@param player Player -- The player that left
]=]
function PlayerDataServiceServer:onPlayerRemoving(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), `expected Player instance, got {typeof(player)}`)

	local profile = playerProfiles[player.UserId]
	if profile then
		profile:EndSession()
		playerProfiles[player.UserId] = nil
	end
end

--[=[
	Gets a player's profile data.
	
	@param userId number -- The user ID to get the profile for
	@return PlayerDataTypes.PlayerProfile? -- The player's profile data or nil if not loaded
]=]
function PlayerDataServiceServer:getProfile(userId: number): PlayerDataTypes.PlayerProfile?
	assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)

	local profile = playerProfiles[userId]
	return profile and profile.Data
end

--[=[
	Mutates a specific path in a player's profile data.
	Domain services should use this instead of directly modifying profile data.
	
	@param userId number -- The user ID to mutate data for
	@param path PlayerDataTypes.ProfilePath -- The profile key to mutate (e.g., "currency", "inventory")
	@param mutator (data: T) -> boolean|nil -- Function that performs the mutation, returning true if data changed
	@return boolean -- True if mutation actually changed data, false otherwise
]=]
function PlayerDataServiceServer:mutate<T>(
	userId: number,
	path: PlayerDataTypes.ProfilePath,
	mutator: (data: T) -> boolean?
): boolean
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
end

export type TransactionOperation = {
	userId: number,
	path: PlayerDataTypes.ProfilePath,
	mutator: (data: any) -> boolean, -- Return false to abort transaction
}

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
function PlayerDataServiceServer:transaction(operations: { TransactionOperation }): boolean
	assert(type(operations) == "table", `operations must be a table, got {type(operations)}`)

	-- Collect affected profiles, validate, lock, and trigger saves to establish rollback point
	local affectedProfiles: { [number]: any } = {}
	local savesPending = 0
	for _, op in operations do
		assert(type(op.userId) == "number", `each operation must have a userId, got {type(op.userId)}`)
		if not affectedProfiles[op.userId] then
			local profile = playerProfiles[op.userId]
			if not profile or not profile.Data then
				log:warn("Cannot execute transaction, profile not loaded for userId:", op.userId)
				return false
			end
			affectedProfiles[op.userId] = profile
			
			-- Immediately lock the profile BEFORE yielding for Save()
			profilesInTransaction[op.userId] = { aborted = false, isPreSaving = true }

			-- Force save to ensure LastSavedData is current
			if profile:IsActive() then
				savesPending += 1
				local conn
				conn = profile.OnAfterSave:Connect(function()
					savesPending -= 1
					local txnState = profilesInTransaction[op.userId]
					if txnState then
						txnState.isPreSaving = false
					end
					conn:Disconnect()
				end)

				local saveSuccess, saveErr = pcall(function()
					profile:Save()
				end)
				if not saveSuccess then
					log:error("Failed to force save during transaction pre-save for userId:", op.userId, "error:", saveErr)
					savesPending -= 1
					conn:Disconnect()
				end
			end
		end
	end

	-- Wait for all saves to complete (with timeout)
	local startTime = os.clock()
	while savesPending > 0 and os.clock() - startTime < 10 do
		task.wait()
	end

	-- Helper function to rollback from LastSavedData
	local function rollbackAll(reason: string)
		for _, profile in affectedProfiles do
			for key, value in sift.Dictionary.copyDeep(profile.LastSavedData) do
				profile.Data[key] = value
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

	log:debug("Transaction completed and saved, #ops:", #operations, "#users:", #{ affectedProfiles })
	return true
end

--[=[
	Broadcasts the current profile data to the specified player.
	Only fires initially to sync to client.
	@param userId number -- The user ID to broadcast the profile for
]=]
function PlayerDataServiceServer:broadcastProfile(userId: number)
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
end

--[=[
	Cleans up event listeners and ends all active sessions.
	@param self PlayerDataServiceServer -- The service instance
]=]
function PlayerDataServiceServer.stop(self: PlayerDataServiceServer)
	-- End all active profile sessions
	for userId, profile in playerProfiles do
		profile:EndSession()
		playerProfiles[userId] = nil
	end

	self.PlayerStore = nil :: any
	janitor:Cleanup()
	log:debug("Service stopped, connections cleaned up")
end

--[=[
	Returns the current state of the service for debugging.
	@return { [string]: any } -- Service state
]=]
function PlayerDataServiceServer:getState(): { [string]: any }
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
end

type PlayerDataServiceServer = typeof(PlayerDataServiceServer) & {
	PlayerStore: ProfileStore.ProfileStore<PlayerDataTypes.PlayerProfile>,
}

return PlayerDataServiceServer :: PlayerDataServiceServer
