--!strict
--[=[
	Unit tests for BankServiceClient — a thin read-facade over StateSyncClientStore.bank. Seeds the atom
	directly and asserts the accessor reads it.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BankServiceClient = require(ReplicatedStorage.Client.Features.Bank.BankServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

return function()
	describe("BankServiceClient", function()
		afterEach(function()
			StateSyncClientStore.bank({ items = {}, currency = {} }) -- restore default for other specs
		end)

		it("returns the bank wrapper from the store", function()
			StateSyncClientStore.bank({ items = { { itemType = "wood", quantity = 5 } }, currency = { jaku = 42 } })
			local bank = BankServiceClient:getBank()
			expect(#bank.items).to.equal(1)
			expect(bank.items[1].itemType).to.equal("wood")
			expect(bank.currency.jaku).to.equal(42)
		end)

		it("returns empty items/currency before the first sync", function()
			StateSyncClientStore.bank({ items = {}, currency = {} })
			local bank = BankServiceClient:getBank()
			expect(#bank.items).to.equal(0)
			expect(next(bank.currency)).to.equal(nil)
		end)
	end)
end
