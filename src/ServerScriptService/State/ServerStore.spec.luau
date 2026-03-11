--!strict
--[=[
	Unit tests for ServerStore — the server-authoritative reactive mirror.
	The load-bearing behaviors are: deep-copy on write (so later in-place profile mutation can't leak
	into a stored snapshot), immutable per-user map replacement (so charm observes a change), and
	clean removal.
]=]

local ServerStore = require(script.Parent.ServerStore)

return function()
	local USER = 999999

	afterEach(function()
		ServerStore.remove(USER)
	end)

	describe("setCurrency", function()
		it("stores a per-user snapshot", function()
			ServerStore.setCurrency(USER, { gold = 100, gems = 5 })
			expect(ServerStore.currencies()[USER].gold).to.equal(100)
			expect(ServerStore.currencies()[USER].gems).to.equal(5)
		end)

		it("deep-copies so later mutation of the source can't leak in", function()
			local live = { gold = 100 }
			ServerStore.setCurrency(USER, live)
			live.gold = 999 -- mutate the source after storing
			expect(ServerStore.currencies()[USER].gold).to.equal(100)
		end)

		it("replaces the per-user map immutably (new table identity)", function()
			local before = ServerStore.currencies()
			ServerStore.setCurrency(USER, { gold = 1 })
			expect(ServerStore.currencies()).never.to.equal(before)
		end)
	end)

	describe("setInventory", function()
		it("deep-copies the inventory snapshot", function()
			local items = { { itemType = "sword", quantity = 1 } }
			ServerStore.setInventory(USER, items)
			items[1].quantity = 99 -- mutate the source after storing
			expect(ServerStore.inventories()[USER][1].quantity).to.equal(1)
		end)
	end)

	describe("syncFromProfile", function()
		it("mirrors both the currency and inventory slices", function()
			ServerStore.syncFromProfile(
				USER,
				{
					currency = { gold = 7 },
					inventory = { { itemType = "potion", quantity = 2 } },
				} :: any
			)
			expect(ServerStore.currencies()[USER].gold).to.equal(7)
			expect(ServerStore.inventories()[USER][1].itemType).to.equal("potion")
		end)
	end)

	describe("sync", function()
		it("mirrors only the named slice, leaving other slices untouched", function()
			ServerStore.setInventory(USER, { { itemType = "shield", quantity = 1 } })
			ServerStore.sync(
				"currency",
				USER,
				{
					currency = { gold = 12 },
					inventory = { { itemType = "potion", quantity = 2 } },
				} :: any
			)
			expect(ServerStore.currencies()[USER].gold).to.equal(12)
			-- The profile's inventory field is ignored — sync("currency", ...) never reads it.
			expect(ServerStore.inventories()[USER][1].itemType).to.equal("shield")
		end)

		it("errors on an unknown slice", function()
			expect(function()
				ServerStore.sync("nope", USER, {} :: any)
			end).to.throw()
		end)
	end)

	describe("isSyncedSlice", function()
		it("is true for a registered slice", function()
			expect(ServerStore.isSyncedSlice("currency")).to.equal(true)
			expect(ServerStore.isSyncedSlice("inventory")).to.equal(true)
		end)

		it("is false for an unregistered path", function()
			expect(ServerStore.isSyncedSlice("quests")).to.equal(false)
		end)
	end)

	describe("getterFor", function()
		it("returns a getter reading the user's slice snapshot", function()
			ServerStore.setCurrency(USER, { gold = 42 })
			local getter = ServerStore.getterFor("currency", USER)
			expect((getter() :: any).gold).to.equal(42)
		end)

		it("errors on an unknown slice", function()
			expect(function()
				ServerStore.getterFor("nope", USER)
			end).to.throw()
		end)
	end)

	describe("remove", function()
		it("drops a user's mirrored currency and inventory", function()
			ServerStore.setCurrency(USER, { gold = 1 })
			ServerStore.setInventory(USER, { { itemType = "sword", quantity = 1 } })
			ServerStore.remove(USER)
			expect(ServerStore.currencies()[USER]).to.equal(nil)
			expect(ServerStore.inventories()[USER]).to.equal(nil)
		end)

		it("is a no-op for an absent user (preserves map identity)", function()
			ServerStore.remove(USER) -- ensure absent
			local before = ServerStore.currencies()
			ServerStore.remove(USER)
			expect(ServerStore.currencies()).to.equal(before)
		end)
	end)
end
