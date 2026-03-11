--!strict
--[=[
	Unit tests for PlayerDataMigrations.

	The production migration list is intentionally empty, so these exercise the core
	`_applyWith` routine with synthetic migrations to prove the versioning, chaining,
	skip-old, baseline, and error-safety behavior.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataMigrations = require(ServerScriptService.Modules.PlayerDataMigrations)

return function()
	describe("PlayerDataMigrations", function()
		describe("apply (production list)", function()
			it("has CURRENT_VERSION = 1 with no migrations registered", function()
				expect(PlayerDataMigrations.CURRENT_VERSION).to.equal(1)
			end)

			it("stamps unversioned data as v1 and leaves fields intact", function()
				local data = { currency = { gold = 5 }, inventory = {} }
				local ok = PlayerDataMigrations.apply(data, nil)
				expect(ok).to.equal(true)
				expect(data._schemaVersion).to.equal(1)
				expect(data.currency.gold).to.equal(5)
			end)
		end)

		describe("_applyWith", function()
			it("is a no-op when the stored version is already current", function()
				local data = { currency = { gold = 5 }, _schemaVersion = 2 }
				local ok = PlayerDataMigrations._applyWith(data, 2, {}, 2)
				expect(ok).to.equal(true)
				expect(data.currency.gold).to.equal(5)
				expect(data._schemaVersion).to.equal(2)
			end)

			it("runs a single migration v1 -> v2", function()
				local migrations = {
					function(d: any)
						d.coins = d.gold
						d.gold = nil
					end,
				}
				local data = { gold = 100 }
				local ok = PlayerDataMigrations._applyWith(data, 1, migrations, 2)
				expect(ok).to.equal(true)
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
				local ok = PlayerDataMigrations._applyWith(data, 1, migrations, 3)
				expect(ok).to.equal(true)
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
				PlayerDataMigrations._applyWith({}, 2, migrations, 3)
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
				PlayerDataMigrations._applyWith({}, nil, migrations, 2)
				expect(ran).to.equal(1)
			end)

			it("returns false and leaves data untouched when a migration errors", function()
				local migrations = {
					function(_d: any)
						error("boom")
					end,
				}
				local data = { gold = 5 }
				local ok = PlayerDataMigrations._applyWith(data, 1, migrations, 2)
				expect(ok).to.equal(false)
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
				PlayerDataMigrations._applyWith(data, 1, migrations, 2)
				expect(data.oldField).to.equal(nil)
				expect(data.newField).to.equal("x")
				expect(data.keep).to.equal("y")
			end)
		end)
	end)
end
