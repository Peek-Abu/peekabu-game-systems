--!strict
--[=[
	Unit tests for ClientStore — the client-side reactive mirror.
	Verifies the loading-state defaults and that the atoms round-trip values.
]=]

local ClientStore = require(script.Parent.ClientStore)

return function()
	describe("initial state", function()
		it("starts with nil currency so the UI can show a loading state", function()
			expect(ClientStore.currency()).to.equal(nil)
		end)

		it("starts with an empty inventory table", function()
			local inventory = ClientStore.inventory()
			expect(type(inventory)).to.equal("table")
			expect(#inventory).to.equal(0)
		end)
	end)

	describe("atom round-trip", function()
		it("stores and returns a currency snapshot", function()
			ClientStore.currency({ gold = 5 })
			local currency = ClientStore.currency()
			expect(currency).to.be.ok()
			expect(currency.gold).to.equal(5)
			ClientStore.currency(nil) -- restore the loading state for other specs
		end)

		it("stores and returns an inventory snapshot", function()
			ClientStore.inventory({ { itemType = "sword", quantity = 1 } })
			local inventory = ClientStore.inventory()
			expect(#inventory).to.equal(1)
			expect(inventory[1].itemType).to.equal("sword")
			ClientStore.inventory({}) -- restore the empty default
		end)
	end)

	describe("setterFor", function()
		it("writes an inbound value into the matching atom", function()
			local setCurrency = ClientStore.setterFor("currency")
			setCurrency({ gold = 11 })
			expect((ClientStore.currency() :: any).gold).to.equal(11)
			ClientStore.currency(nil) -- restore the loading state for other specs
		end)

		it("errors on an unknown slice", function()
			expect(function()
				ClientStore.setterFor("nope")
			end).to.throw()
		end)
	end)
end
