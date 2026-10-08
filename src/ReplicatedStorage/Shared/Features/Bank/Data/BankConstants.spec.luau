local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BankConstants = require(ReplicatedStorage.Shared.Features.Bank.Data.BankConstants)

return function()
	describe("CAPACITY", function()
		it("is a positive integer (the flat total-entry cap for bank.items)", function()
			expect(type(BankConstants.CAPACITY)).to.equal("number")
			expect(BankConstants.CAPACITY > 0).to.equal(true)
			expect(BankConstants.CAPACITY % 1 == 0).to.equal(true)
		end)
	end)
end
