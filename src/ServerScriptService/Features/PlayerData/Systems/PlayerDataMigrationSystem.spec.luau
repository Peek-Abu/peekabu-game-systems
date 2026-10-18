--!strict
--[=[
	Unit tests for PlayerDataMigrationSystem.

	The production list's cases are under "apply (production list)"; the core `_applyWith` routine is
	exercised with synthetic migrations to prove the versioning, chaining, skip-old, baseline, and
	error-safety behavior.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataMigrationSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataMigrationSystem)

return function()
	describe("PlayerDataMigrationSystem", function()
		describe("apply (production list)", function()
			it("has CURRENT_VERSION = 2 (one migration registered)", function()
				expect(PlayerDataMigrationSystem.CURRENT_VERSION).to.equal(2)
			end)

			it("migrates unversioned data to current and leaves unrelated fields intact", function()
				local data = { currency = { gold = 5 }, inventory = { items = {} } }
				local result = PlayerDataMigrationSystem.apply(data, nil)
				expect(result).to.equal("ok")
				expect(data._schemaVersion).to.equal(PlayerDataMigrationSystem.CURRENT_VERSION)
				expect(data.currency.gold).to.equal(5)
			end)

			it("v1 -> v2 drops the merged volume settings and keeps the ones they merged into", function()
				-- "Music & ambience" is musicVolume, "Sound effects" is sfxVolume: their saved values carry over as
				-- they are; the merged uiVolume / ambientVolume are removed, and other settings are untouched.
				local data = {
					account = {
						settings = {
							values = {
								musicVolume = 0.4,
								sfxVolume = 0.6,
								uiVolume = 0.2,
								ambientVolume = 0,
								cameraShake = 0.5,
							},
						},
					},
				}
				expect(PlayerDataMigrationSystem.apply(data, 1)).to.equal("ok")
				local values = data.account.settings.values
				expect(values.musicVolume).to.equal(0.4)
				expect(values.sfxVolume).to.equal(0.6)
				expect(values.cameraShake).to.equal(0.5)
				expect(values.uiVolume).to.equal(nil)
				expect(values.ambientVolume).to.equal(nil)
				expect(data._schemaVersion).to.equal(2)
			end)

			it("v1 -> v2 is safe on a profile without stored settings", function()
				local data = { account = {} }
				expect(PlayerDataMigrationSystem.apply(data, 1)).to.equal("ok")
				expect(data.account.settings).to.equal(nil)
				local bare = { account = { settings = { values = {} } } }
				expect(PlayerDataMigrationSystem.apply(bare, 1)).to.equal("ok")
				expect(next(bare.account.settings.values)).to.equal(nil)
			end)
		end)

		describe("_applyWith", function()
			it("is a no-op when the stored version is already current", function()
				local data = { currency = { gold = 5 }, _schemaVersion = 2 }
				local result = PlayerDataMigrationSystem._applyWith(data, 2, {}, 2)
				expect(result).to.equal("ok")
				expect(data.currency.gold).to.equal(5)
				expect(data._schemaVersion).to.equal(2)
			end)

			it("returns 'too_new' and leaves data untouched when the profile is newer than the server", function()
				-- Rollback / mixed-version deploy: a v3-tagged profile loaded on a v2 server. It must NOT
				-- be migrated and its version must NOT be stamped down (that would double-migrate later).
				local data = { coins = 42, _schemaVersion = 3 }
				local result = PlayerDataMigrationSystem._applyWith(data, 3, {}, 2)
				expect(result).to.equal("too_new")
				expect(data.coins).to.equal(42)
				expect(data._schemaVersion).to.equal(3) -- unchanged, NOT stamped down to 2
			end)

			it("runs a single migration v1 -> v2", function()
				local migrations = {
					function(d: any)
						d.coins = d.gold
						d.gold = nil
					end,
				}
				local data = { gold = 100 }
				local result = PlayerDataMigrationSystem._applyWith(data, 1, migrations, 2)
				expect(result).to.equal("ok")
				expect(data.coins).to.equal(100)
				expect(data.gold).to.equal(nil)
				expect(data._schemaVersion).to.equal(2)
			end)

			it("runs a chain of migrations v1 -> v3", function()
				local migrations = {
					function(d: any)
						d.a = true
					end,
					function(d: any)
						d.b = true
					end,
				}
				local data = {}
				local result = PlayerDataMigrationSystem._applyWith(data, 1, migrations, 3)
				expect(result).to.equal("ok")
				expect(data.a).to.equal(true)
				expect(data.b).to.equal(true)
				expect(data._schemaVersion).to.equal(3)
			end)

			it("only runs migrations newer than the stored version", function()
				local ran = {}
				local migrations = {
					function(_d: any)
						table.insert(ran, 1)
					end,
					function(_d: any)
						table.insert(ran, 2)
					end,
				}
				PlayerDataMigrationSystem._applyWith({}, 2, migrations, 3)
				-- Stored at v2, so only migration[2] (v2 -> v3) should run.
				expect(#ran).to.equal(1)
				expect(ran[1]).to.equal(2)
			end)

			it("treats a nil version as the v1 baseline", function()
				local ran = 0
				local migrations = {
					function(_d: any)
						ran += 1
					end,
				}
				PlayerDataMigrationSystem._applyWith({}, nil, migrations, 2)
				expect(ran).to.equal(1)
			end)

			it("returns 'failed' and leaves data untouched when a migration errors", function()
				local migrations = {
					function(_d: any)
						error("boom")
					end,
				}
				local data = { gold = 5 }
				local result = PlayerDataMigrationSystem._applyWith(data, 1, migrations, 2)
				expect(result).to.equal("failed")
				expect(data.gold).to.equal(5)
				expect(data._schemaVersion).to.equal(nil)
			end)

			it("removes keys that a migration deletes", function()
				local migrations = {
					function(d: any)
						d.newField = d.oldField
						d.oldField = nil
					end,
				}
				local data = { oldField = "x", keep = "y" }
				PlayerDataMigrationSystem._applyWith(data, 1, migrations, 2)
				expect(data.oldField).to.equal(nil)
				expect(data.newField).to.equal("x")
				expect(data.keep).to.equal("y")
			end)
		end)
	end)
end
