--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SignalTyped = require(ReplicatedStorage.Shared.Modules.SignalTyped)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local log = Logger.new("PlayerDataServiceClient")

-- Only ProfileLoaded lives here (owned by this service, not a domain service). The typed local
-- drives the signal's parameter inference (see SignalTyped) so no cast is needed.
local profileLoaded: SignalTyped.Signal<PlayerDataTypes.PlayerProfile> = SignalTyped.new()

local janitor = Janitor.new()
local profile: PlayerDataTypes.PlayerProfile? = nil

--[=[
	Public interface of the service — the single place method/field types are declared.
	See the server service modules for the standard service-module shape (lean annotated
	literal). `ProfileLoaded` is a declared field (the signal owned by this service).
	The generic `mutate` is declared here so the method body needs no inline annotation.
]=]
export type PlayerDataServiceClient = {
	ProfileLoaded: SignalTyped.Signal<PlayerDataTypes.PlayerProfile>,

	init: (self: PlayerDataServiceClient) -> (),
	stop: (self: PlayerDataServiceClient) -> (),
	mutate: <T>(
		self: PlayerDataServiceClient,
		path: PlayerDataTypes.ProfilePath,
		mutator: (data: T) -> boolean?
	) -> boolean,
	getProfile: (self: PlayerDataServiceClient) -> PlayerDataTypes.PlayerProfile?,
	getState: (self: PlayerDataServiceClient) -> { [string]: any },
	_setProfileForTesting: (self: PlayerDataServiceClient, newProfile: PlayerDataTypes.PlayerProfile?) -> (),
}

local PlayerDataServiceClient: PlayerDataServiceClient = {
	ProfileLoaded = profileLoaded,

	--[=[
		Initializes the PlayerDataServiceClient and sets up event listeners.
		@param self PlayerDataServiceClient -- The service instance
	]=]
	init = function(self)
		-- Require event right before setting up listener to ensure packet registration and listener setup happen together
		local PlayerDataEvents = require(ReplicatedStorage.Shared.Events.PlayerDataEvents)

		-- Initial profile sync from server (server is authoritative, no validation needed)
		janitor:Add(
			PlayerDataEvents.packets.PlayerProfileUpdate.listen(
				function(data: PlayerDataTypes.PlayerProfile & { userId: number })
					local newProfile = {
						currency = data.currency,
						inventory = data.inventory,
					}
					profile = newProfile
					log:debug("Profile loaded for userId:", data.userId)
					self.ProfileLoaded:Fire(newProfile)
				end
			)
		)

		-- Listener is live: tell the server we're ready for the initial profile sync.
		PlayerDataEvents.packets.PlayerReady.send()
	end,

	--[=[
		Cleans up event listeners when the service is stopped.
		@param self PlayerDataServiceClient -- The service instance
	]=]
	stop = function(_self)
		janitor:Cleanup()
		log:debug("Service stopped, connections cleaned up")
	end,

	--[=[
		Generic mutation method. Mutates a path in the profile.
		Domain services call this with a typed mutator function, then fire their own signal.

		@param path PlayerDataTypes.ProfilePath -- The profile key to mutate (e.g., "currency", "inventory")
		@param mutator (data: T) -> boolean? -- Function that performs the mutation, returning true if changed
		@return boolean -- True if mutation actually changed data, false otherwise
	]=]
	mutate = function(_self, path, mutator)
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
	end,

	--[=[
		Gets the local player's profile data.
		@return PlayerDataTypes.PlayerProfile? -- The player's profile or nil if not loaded
	]=]
	getProfile = function(_self)
		return profile
	end,

	--[=[
		Returns the current state of the service for debugging.
		@return { [string]: any } -- Service state
	]=]
	getState = function(_self)
		return {
			hasProfile = profile ~= nil,
			currency = profile and profile.currency or nil,
			inventoryCount = profile and #profile.inventory or 0,
		}
	end,

	--[=[
		TEST SEAM — not for use in game code.
		Sets (or clears, when nil) the cached profile so spec files can exercise
		getProfile()/mutate()/getState() without a live network sync. Game code receives its
		profile through the PlayerProfileUpdate listener set up in init().
		@param newProfile PlayerDataTypes.PlayerProfile? -- The profile to set, or nil to clear
	]=]
	_setProfileForTesting = function(_self, newProfile)
		profile = newProfile
	end,
}

return PlayerDataServiceClient
