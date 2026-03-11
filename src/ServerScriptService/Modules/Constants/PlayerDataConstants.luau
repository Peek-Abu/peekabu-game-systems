--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local PlayerDataMigrations = require(ServerScriptService.Modules.PlayerDataMigrations)

--[=[
	Constants and configuration for the PlayerData system.
	@class PlayerDataConstants
]=]
local PlayerDataConstants = {
	--[=[
		Template for new player profiles.
		Used by ProfileStore to initialize new players.
		@prop PROFILE_TEMPLATE PlayerDataTypes.PlayerProfile -- Default player data structure
	]=]
	-- New profiles are stamped with the current schema version so they skip migrations.
	-- Domain services append their own keys via registerProfilePath.
	PROFILE_TEMPLATE = { _schemaVersion = PlayerDataMigrations.CURRENT_VERSION } :: PlayerDataTypes.PlayerProfile,
}

--[=[
	Registers a new profile path and its default initial data structure dynamically.
	This should be called by service plugins before PlayerDataServiceServer initializes.
	@param path string -- The root key in the profile
	@param defaultData any -- The default value for this key
]=]
function PlayerDataConstants.registerProfilePath(path: string, defaultData: any)
	assert(type(path) == "string", "ProfilePath must be a string")
	assert(
		PlayerDataConstants.PROFILE_TEMPLATE[path] == nil,
		`[PlayerDataConstants] ProfilePath "{path}" is already registered!`
	)
	PlayerDataConstants.PROFILE_TEMPLATE[path] = defaultData
end

return PlayerDataConstants
