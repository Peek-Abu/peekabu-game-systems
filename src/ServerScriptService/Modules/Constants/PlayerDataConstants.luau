--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local PlayerDataMigrations = require(ServerScriptService.Modules.PlayerDataMigrations)
local sift = require(ReplicatedStorage.Packages.sift)

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

-- Optional invariant validators keyed by profile path, populated by registerProfilePath. A path with
-- no entry (the default) is unvalidated — mutate()/transaction() skip the check for it.
local pathValidators: { [string]: PathValidator } = {}

-- Once PlayerDataService consumes the template (init), further registration would silently omit a
-- slice from new profiles. Seal turns that latent bug into a loud error.
local sealed = false

--[=[
	Freezes the profile template against further registration. Called by PlayerDataServiceServer
	once it has built the store from the template; any registerProfilePath after this errors.
	Idempotent.
]=]
function PlayerDataConstants.seal()
	sealed = true
end

--[=[
	Registers a new profile path and its default initial data structure dynamically.
	This should be called by service plugins before PlayerDataServiceServer initializes.
	@param path string -- The root key in the profile
	@param defaultData any -- The default value for this key
	@param validator PathValidator? -- Optional invariant check enforced by mutate()/transaction()
]=]
function PlayerDataConstants.registerProfilePath(path: string, defaultData: any, validator: PathValidator?)
	assert(type(path) == "string", "ProfilePath must be a string")
	assert(
		not sealed,
		`[PlayerDataConstants] Cannot register ProfilePath "{path}" after the template is sealed `
			.. "(PlayerDataService already initialized). Require the owning service module during boot, "
			.. 'before initService("PlayerDataServiceServer").'
	)
	assert(
		PlayerDataConstants.PROFILE_TEMPLATE[path] == nil,
		`[PlayerDataConstants] ProfilePath "{path}" is already registered!`
	)
	if validator ~= nil then
		assert(type(validator) == "function", `validator for "{path}" must be a function, got {type(validator)}`)
		pathValidators[path] = validator
	end
	-- Deep-copy so the template owns an independent table. Callers pass literals (e.g. { gold = 100 });
	-- without this, ProfileStore's per-profile reconcile is the *only* thing preventing every new
	-- profile from aliasing one shared mutable default. Scalars pass through untouched.
	PlayerDataConstants.PROFILE_TEMPLATE[path] = if type(defaultData) == "table"
		then sift.Dictionary.copyDeep(defaultData)
		else defaultData
end

--[=[
	Returns the invariant validator registered for a path, or nil if that path is unvalidated.
	PlayerDataService calls this after a mutator runs to enforce the slice's invariant.
	@param path string -- The profile path
	@return PathValidator? -- The validator, or nil
]=]
function PlayerDataConstants.getValidator(path: string): PathValidator?
	return pathValidators[path]
end

return PlayerDataConstants
