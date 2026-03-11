--!strict
--[=[
	PlayerDataMigrations: versioned, ordered schema migrations for player profiles.

	ProfileStore's `Reconcile()` backfills NEW template fields, but it cannot rename a field,
	change a field's type, or remove a deprecated field. Those changes need explicit migrations.

	## Versioning model
	- Every profile carries a `_schemaVersion`. The profile template stamps new profiles with
	  the current version; profiles saved before versioning existed have no field and are
	  treated as the v1 baseline.
	- `MIGRATIONS[v]` upgrades a profile FROM version `v` TO `v + 1`. The list is contiguous
	  and 1-indexed, so `CURRENT_VERSION = 1 + #MIGRATIONS`.
	- Migrations mutate the `data` table in place, but run against a deep COPY: a migration
	  that errors leaves the live profile untouched (`apply` returns `false`) so nothing
	  half-migrated is ever persisted.

	## Adding a migration
	1. Append a function to `MIGRATIONS` (its index is the version it upgrades FROM).
	2. Update the profile template / `registerProfilePath` defaults so NEW profiles already
	   match the new shape.
	3. Add a case to PlayerDataMigrations.spec.luau.

	@class PlayerDataMigrations
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sift = require(ReplicatedStorage.Packages.sift)

export type Migration = (data: any) -> ()

-- The v1 baseline: profiles with no `_schemaVersion` predate versioning and start here.
local BASELINE_VERSION = 1

--[=[
	Ordered migrations. `MIGRATIONS[v]` upgrades a v profile to v + 1.

	Example (uncomment and adapt when you change the profile shape):
		[1] = function(data) -- v1 -> v2: rename currency.gold to currency.coins
			data.currency.coins = data.currency.gold
			data.currency.gold = nil
		end,
]=]
local MIGRATIONS: { Migration } = {}

local PlayerDataMigrations = {}

PlayerDataMigrations.CURRENT_VERSION = 1 + #MIGRATIONS

--[=[
	Core migration routine, parameterized over the migration list and target version so it can
	be unit-tested with synthetic migrations. On success, `data` is mutated in place to match
	`currentVersion`.

	@param data any -- The profile data table (mutated in place only on success)
	@param fromVersion number? -- The profile's stored schema version (nil = v1 baseline)
	@param migrations { Migration } -- Ordered migrations; index v upgrades v -> v + 1
	@param currentVersion number -- The version to migrate up to
	@return boolean -- true on success (data is at currentVersion); false if a migration errored
]=]
function PlayerDataMigrations._applyWith(
	data: any,
	fromVersion: number?,
	migrations: { Migration },
	currentVersion: number
): boolean
	local version = fromVersion or BASELINE_VERSION

	if version >= currentVersion then
		data._schemaVersion = currentVersion
		return true
	end

	-- Migrate a deep copy so a mid-chain error can never persist a half-migrated profile.
	local working = sift.Dictionary.copyDeep(data)
	local ok, err = pcall(function()
		for v = version, currentVersion - 1 do
			local migration = migrations[v]
			assert(migration, `missing migration for v{v} -> v{v + 1}`)
			migration(working)
		end
	end)

	if not ok then
		warn(`[PlayerDataMigrations] migration from v{version} failed: {tostring(err)}`)
		return false
	end

	working._schemaVersion = currentVersion

	-- Commit the migrated copy back onto the original table, preserving its identity so
	-- ProfileStore keeps tracking it. Clearing first handles keys a migration removed.
	for key in data do
		data[key] = nil
	end
	for key, value in working do
		data[key] = value
	end

	return true
end

--[=[
	Migrates a profile's data up to CURRENT_VERSION using the registered migrations.
	@param data any -- The profile data table (mutated in place only on success)
	@param fromVersion number? -- The profile's stored `_schemaVersion` (nil = v1 baseline)
	@return boolean -- true on success; false if a migration errored (caller must not persist)
]=]
function PlayerDataMigrations.apply(data: any, fromVersion: number?): boolean
	return PlayerDataMigrations._applyWith(data, fromVersion, MIGRATIONS, PlayerDataMigrations.CURRENT_VERSION)
end

return PlayerDataMigrations
