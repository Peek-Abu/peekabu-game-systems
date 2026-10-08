--!strict
--[=[
	Unit tests for StatServiceClient — a thin read-facade over StateSyncClientStore.stats.
	Seeds the atom directly and asserts the accessors read/derive from it. There is no
	listener/signal to exercise; replication is covered by the StateSync/StateSyncClientStore specs.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatServiceClient = require(ReplicatedStorage.Client.Features.Stat.StatServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)
local StatConstants = require(ReplicatedStorage.Shared.Features.Stat.Data.StatConstants)

return function()
	describe("StatServiceClient", function()
		beforeAll(function()
			-- Idempotent: ItemContentRegistry.init() no-ops if already seeded in this VM. getState's derived
			-- field folds in equipment bonuses via EquipmentBonusFormulas.aggregate, which asks the registry
			-- for each equipped itemType's statBonuses.
			ItemContentRegistry.init()
		end)

		afterEach(function()
			StateSyncClientStore.stats(nil) -- restore the loading state for other specs
			StateSyncClientStore.equipment({ slots = {} }) -- restore the empty default for other specs
		end)

		describe("getStats", function()
			it("returns the stats snapshot from the store", function()
				StateSyncClientStore.stats({ totalXp = 160, investments = { health = 2 } })
				local stats = StatServiceClient:getStats()
				expect(stats).to.be.ok()
				expect(stats and stats.totalXp).to.equal(160)
			end)

			it("returns nil before the first sync", function()
				StateSyncClientStore.stats(nil)
				expect(StatServiceClient:getStats()).to.equal(nil)
			end)
		end)

		describe("getProgress", function()
			it("returns the level and xp-into-level for the synced totalXp", function()
				StateSyncClientStore.stats({ totalXp = 160, investments = { health = 2 } })
				local progress = StatServiceClient:getProgress()
				expect(progress).to.be.ok()
				expect(progress and progress.level).to.equal(4)
				expect(progress and progress.xpIntoLevel).to.equal(10)
			end)

			it("returns nil before the first sync", function()
				StateSyncClientStore.stats(nil)
				expect(StatServiceClient:getProgress()).to.equal(nil)
			end)
		end)

		describe("getDerived", function()
			it("returns the derived stat values for the synced investments", function()
				StateSyncClientStore.stats({ totalXp = 160, investments = { health = 2 } })
				local derived = StatServiceClient:getDerived()
				expect(derived).to.be.ok()
				expect(derived and derived.health).to.equal(210)
			end)

			it("returns nil before the first sync", function()
				StateSyncClientStore.stats(nil)
				expect(StatServiceClient:getDerived()).to.equal(nil)
			end)
		end)

		describe("getUnspentPoints", function()
			it("returns earned minus spent, per pool", function()
				StateSyncClientStore.stats({ totalXp = 160, investments = { health = 2 } })
				local unspent = StatServiceClient:getUnspentPoints()
				expect(unspent).to.be.ok()
				-- level 4 has earned 3 main / 9 sub; health (main) spent 2 -> main unspent 1, sub unspent 9
				expect(unspent and unspent.main).to.equal(1)
				expect(unspent and unspent.sub).to.equal(9)
			end)

			it("returns nil before the first sync", function()
				StateSyncClientStore.stats(nil)
				expect(StatServiceClient:getUnspentPoints()).to.equal(nil)
			end)
		end)

		describe("getState", function()
			it("reports level/xp/unspent points and full derived stats when synced", function()
				-- level 8: xpForLevel(8) = 25*7*8/2 = 700, so xpIntoLevel = 0, xpToNext = 8*25 = 200.
				-- Earned at level 8: main = 7, sub = 21. health (main) spent 2 -> unspentMain = 5,
				-- unspentSub = 21 (nothing spent from sub).
				StateSyncClientStore.stats({ totalXp = 700, investments = { health = 2 } })
				local state = StatServiceClient:getState()
				expect(state.synced).to.equal(true)
				expect(state.level).to.equal(8)
				expect(state.xpIntoLevel).to.equal(0)
				expect(state.xpToNext).to.equal(200)
				expect(state.unspentMain).to.equal(5)
				expect(state.unspentSub).to.equal(21)
				local derived = state.derived :: { [string]: number }
				expect(derived.health).to.equal(210) -- 200 + 2*5, no equipment bonus yet
			end)

			it("folds in equipment bonuses via StateSyncClientStore.equipment", function()
				StateSyncClientStore.stats({ totalXp = 700, investments = {} })
				StateSyncClientStore.equipment({ slots = { helmet = { itemType = "chambered-helmet", uid = "h1" } } })
				local state = StatServiceClient:getState()
				local derived = state.derived :: { [string]: number }
				expect(derived.rotEndurance).to.equal(StatConstants.DEFINITIONS.rotEndurance.base + 8) -- + chambered-helmet's bonus
			end)

			it("returns { synced = false } before the first sync", function()
				StateSyncClientStore.stats(nil)
				local state = StatServiceClient:getState()
				expect(state).to.be.ok()
				expect(state.synced).to.equal(false)
				expect(state.level).to.equal(nil)
			end)
		end)
	end)
end
