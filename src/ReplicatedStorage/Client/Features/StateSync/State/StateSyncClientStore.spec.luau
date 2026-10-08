--!strict
--[=[
	Unit tests for StateSyncClientStore — the client-side reactive mirror.
	Verifies the loading-state defaults and that the atoms round-trip values.
]=]

local StateSyncClientStore = require(script.Parent.StateSyncClientStore)

return function()
	describe("initial state", function()
		it("starts with nil currency so the UI can show a loading state", function()
			expect(StateSyncClientStore.currency()).to.equal(nil)
		end)

		it("starts with an empty inventory wrapper", function()
			local inventory = StateSyncClientStore.inventory()
			expect(type(inventory)).to.equal("table")
			expect(type(inventory.items)).to.equal("table")
			expect(#inventory.items).to.equal(0)
		end)
	end)

	describe("atom round-trip", function()
		it("stores and returns a currency snapshot", function()
			StateSyncClientStore.currency({ jaku = 5 })
			local currency = StateSyncClientStore.currency()
			expect(currency).to.be.ok()
			expect(currency.jaku).to.equal(5)
			StateSyncClientStore.currency(nil) -- restore the loading state for other specs
		end)

		it("stores and returns an inventory snapshot", function()
			StateSyncClientStore.inventory({ items = { { itemType = "sword", quantity = 1 } } })
			local inventory = StateSyncClientStore.inventory()
			expect(#inventory.items).to.equal(1)
			expect(inventory.items[1].itemType).to.equal("sword")
			StateSyncClientStore.inventory({ items = {} }) -- restore the empty default
		end)
	end)

	describe("setterFor", function()
		it("writes an inbound value into the matching atom", function()
			local setCurrency = StateSyncClientStore.setterFor("currency")
			setCurrency({ jaku = 11 })
			expect((StateSyncClientStore.currency() :: any).jaku).to.equal(11)
			StateSyncClientStore.currency(nil) -- restore the loading state for other specs
		end)

		it("errors on an unknown slice", function()
			expect(function()
				StateSyncClientStore.setterFor("nope")
			end).to.throw()
		end)
	end)
end
