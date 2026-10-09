--!strict
--[=[
	Unit tests for StateSyncServerStore — the server-authoritative reactive mirror.
	The load-bearing behaviors are: deep-copy on write (so later in-place profile mutation can't leak
	into a stored snapshot), immutable per-user map replacement (so charm observes a change), and
	clean removal.
]=]

local StateSyncServerStore = require(script.Parent.StateSyncServerStore)

return function()
	local USER = 999999

	afterEach(function()
		StateSyncServerStore.remove(USER)
	end)

	describe("setCurrency", function()
		it("stores a per-user snapshot", function()
			StateSyncServerStore.setCurrency(USER, { coins = 100 })
			expect(StateSyncServerStore.currencies()[USER].coins).to.equal(100)
		end)

		it("deep-copies so later mutation of the source can't leak in", function()
			local live = { coins = 100 }
			StateSyncServerStore.setCurrency(USER, live)
			live.coins = 999 -- mutate the source after storing
			expect(StateSyncServerStore.currencies()[USER].coins).to.equal(100)
		end)

		it("replaces the per-user map immutably (new table identity)", function()
			local before = StateSyncServerStore.currencies()
			StateSyncServerStore.setCurrency(USER, { coins = 1 })
			expect(StateSyncServerStore.currencies()).never.to.equal(before)
		end)
	end)

	describe("setInventory", function()
		it("deep-copies the inventory snapshot", function()
			local inventory = { items = { { itemType = "sword", quantity = 1 } } }
			StateSyncServerStore.setInventory(USER, inventory)
			inventory.items[1].quantity = 99 -- mutate the source after storing
			expect(StateSyncServerStore.inventories()[USER].items[1].quantity).to.equal(1)
		end)
	end)

	describe("syncFromProfile", function()
		it("mirrors both the currency and inventory slices", function()
			StateSyncServerStore.syncFromProfile(USER, {
				slotState = { active = 1, epoch = 1 },
				account = {
					itemMint = { nextUid = 1 },
					premium = { balance = 0 },
					receipts = { ids = {} },
					entitlements = { owned = {} },
					settings = { values = {} },
					dailyReward = { lastDay = 0, streak = 0 },
					titles = { earned = {} },
				},
				slots = {
					{
						currency = { coins = 7 },
						inventory = { items = { { itemType = "potion", quantity = 2 } } },
						equippedTitle = {},
					},
				},
			})
			expect(StateSyncServerStore.currencies()[USER].coins).to.equal(7)
			expect(StateSyncServerStore.inventories()[USER].items[1].itemType).to.equal("potion")
		end)
	end)

	describe("sync", function()
		it("mirrors only the named slice, leaving other slices untouched", function()
			StateSyncServerStore.setInventory(USER, { items = { { itemType = "shield", quantity = 1 } } })
			StateSyncServerStore.sync("currency", USER, {
				slotState = { active = 1, epoch = 1 },
				account = {
					itemMint = { nextUid = 1 },
					premium = { balance = 0 },
					receipts = { ids = {} },
					entitlements = { owned = {} },
					settings = { values = {} },
					dailyReward = { lastDay = 0, streak = 0 },
					titles = { earned = {} },
				},
				slots = {
					{
						currency = { coins = 12 },
						inventory = { items = { { itemType = "potion", quantity = 2 } } },
						equippedTitle = {},
					},
				},
			})
			expect(StateSyncServerStore.currencies()[USER].coins).to.equal(12)
			-- The profile's inventory field is ignored — sync("currency", ...) never reads it.
			expect(StateSyncServerStore.inventories()[USER].items[1].itemType).to.equal("shield")
		end)

		it("errors on an unknown slice", function()
			expect(function()
				StateSyncServerStore.sync("nope", USER, {} :: any)
			end).to.throw()
		end)

		-- sync() only projects the profile it is handed through the registry reader, so a hand-built
		-- two-slot profile exercises the active-slot gate even while PlayerDataConstants.MAX_SLOTS = 1.
		it("mirrors the ACTIVE slot's value and never an inactive slot's", function()
			local profile = {
				slotState = { active = 1, epoch = 1 },
				account = {
					itemMint = { nextUid = 1 },
					premium = { balance = 0 },
					receipts = { ids = {} },
					entitlements = { owned = {} },
					settings = { values = {} },
					dailyReward = { lastDay = 0, streak = 0 },
					titles = { earned = {} },
				},
				slots = {
					{
						currency = { coins = 7 },
						inventory = { items = {} },
						equippedTitle = {},
					},
					{
						currency = { coins = 999 },
						inventory = { items = {} },
						equippedTitle = {},
					},
				},
			}

			StateSyncServerStore.sync("currency", USER, profile)
			expect(StateSyncServerStore.currencies()[USER].coins).to.equal(7)
			expect(StateSyncServerStore.currencies()[USER].coins).to.never.equal(999)

			profile.slotState.active = 2
			StateSyncServerStore.sync("currency", USER, profile)
			expect(StateSyncServerStore.currencies()[USER].coins).to.equal(999)
		end)
	end)

	describe("isSyncedSlice", function()
		it("is true for a registered slice", function()
			expect(StateSyncServerStore.isSyncedSlice("currency")).to.equal(true)
			expect(StateSyncServerStore.isSyncedSlice("inventory")).to.equal(true)
			expect(StateSyncServerStore.isSyncedSlice("titles")).to.equal(true)
			expect(StateSyncServerStore.isSyncedSlice("equippedTitle")).to.equal(true)
		end)

		it("is false for an unregistered path", function()
			expect(StateSyncServerStore.isSyncedSlice("quests")).to.equal(false)
		end)
	end)

	describe("getterFor", function()
		it("returns a getter reading the user's slice snapshot", function()
			StateSyncServerStore.setCurrency(USER, { coins = 42 })
			local getter = StateSyncServerStore.getterFor("currency", USER)
			expect((getter() :: any).coins).to.equal(42)
		end)

		it("errors on an unknown slice", function()
			expect(function()
				StateSyncServerStore.getterFor("nope", USER)
			end).to.throw()
		end)
	end)

	describe("remove", function()
		it("drops a user's mirrored currency and inventory", function()
			StateSyncServerStore.setCurrency(USER, { coins = 1 })
			StateSyncServerStore.setInventory(USER, { items = { { itemType = "sword", quantity = 1 } } })
			StateSyncServerStore.remove(USER)
			expect(StateSyncServerStore.currencies()[USER]).to.equal(nil)
			expect(StateSyncServerStore.inventories()[USER]).to.equal(nil)
		end)

		it("is a no-op for an absent user (preserves map identity)", function()
			StateSyncServerStore.remove(USER) -- ensure absent
			local before = StateSyncServerStore.currencies()
			StateSyncServerStore.remove(USER)
			expect(StateSyncServerStore.currencies()).to.equal(before)
		end)
	end)
end
