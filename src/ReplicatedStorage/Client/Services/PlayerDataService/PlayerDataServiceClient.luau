--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local PlayerDataEvents = require(ReplicatedStorage.Shared.Events.PlayerDataEvents)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local log = Logger.new("PlayerDataServiceClient")

local PlayerDataServiceClient = {}

-- Only ProfileLoaded lives here (owned by this service, not a domain service)
PlayerDataServiceClient.ProfileLoaded = Signal() :: Signal.Signal<PlayerDataTypes.PlayerProfile>

local janitor = Janitor.new()
local profile: PlayerDataTypes.PlayerProfile? = nil

--[=[
	Initializes the PlayerDataServiceClient and sets up event listeners.
	@param self PlayerDataServiceClient -- The service instance
]=]
function PlayerDataServiceClient.init(_self: PlayerDataServiceClient)
	-- Initial profile sync from server (server is authoritative, no validation needed)
	janitor:Add(
		PlayerDataEvents.packets.PlayerProfileUpdate.listen(
			function(data: PlayerDataTypes.PlayerProfile & { userId: number })
				profile = {
					currency = data.currency,
					inventory = data.inventory,
				}
				log:debug("Profile loaded for userId:", data.userId)
				PlayerDataServiceClient.ProfileLoaded:Fire(profile)
			end
		)
	)
end

--[=[
	Cleans up event listeners when the service is stopped.
	@param self PlayerDataServiceClient -- The service instance
]=]
function PlayerDataServiceClient.stop(_self: PlayerDataServiceClient)
	janitor:Cleanup()
	log:debug("Service stopped, connections cleaned up")
end

--[=[
	Generic mutation method. Mutates a path in the profile.
	Domain services call this with a typed mutator function, then fire their own signal.
	
	@param path PlayerDataTypes.ProfilePath -- The profile key to mutate (e.g., "currency", "inventory")
	@param mutator (data: T) -> boolean? -- Function that performs the mutation, returning true if changed
	@return boolean -- True if mutation actually changed data, false otherwise
]=]
function PlayerDataServiceClient:mutate<T>(path: PlayerDataTypes.ProfilePath, mutator: (data: T) -> boolean?): boolean
	if not profile then
		log:warn("Cannot mutate, profile not loaded")
		return false
	end

	local data = (profile :: any)[path]
	if data == nil then
		log:warn("Cannot mutate, path not found:", path)
		return false
	end

	local success = mutator(data)
	if not success then
		return false
	end

	log:debug("Mutated path:", path)
	return true
end

--[=[
	Gets the local player's profile data.
	@return PlayerDataTypes.PlayerProfile? -- The player's profile or nil if not loaded
]=]
function PlayerDataServiceClient:getProfile(): PlayerDataTypes.PlayerProfile?
	return profile
end

--[=[
	Returns the current state of the service for debugging.
	@return { [string]: any } -- Service state
]=]
function PlayerDataServiceClient:getState(): { [string]: any }
	return {
		hasProfile = profile ~= nil,
		currency = profile and profile.currency or nil,
		inventoryCount = profile and #profile.inventory or 0,
	}
end

type PlayerDataServiceClient = typeof(PlayerDataServiceClient)
return PlayerDataServiceClient :: PlayerDataServiceClient
