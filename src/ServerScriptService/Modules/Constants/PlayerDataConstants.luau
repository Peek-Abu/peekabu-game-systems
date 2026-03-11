--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

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
	PROFILE_TEMPLATE = {} :: PlayerDataTypes.PlayerProfile,
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
