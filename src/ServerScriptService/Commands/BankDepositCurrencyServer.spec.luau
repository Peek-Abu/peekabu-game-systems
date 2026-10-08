--!strict
--[=[
	Unit tests for the DepositCurrency Cmdr command implementation. Mock strategy: patch
	BankService.depositCurrency (see AddCurrencyServer.spec for the rationale).
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local BankService = require(ServerScriptService.Features.Bank.BankServiceServer)
local depositCurrencyCommand = require(ServerScriptService.Commands.BankDepositCurrencyServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("BankDepositCurrencyServer", function()
		local _orig
		local calls: { { userId: number, currencyType: string, amount: number } } = {}
		local nextResult = true
		local nextReason: string? = nil

		beforeAll(function()
			_orig = BankService.depositCurrency
			BankService.depositCurrency = function(_self: any, userId: number, currencyType: any, amount: number)
				table.insert(calls, { userId = userId, currencyType = currencyType, amount = amount })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			BankService.depositCurrency = _orig
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
			nextReason = nil
		end)

		it("forwards the target's UserId, currency type, and amount", function()
			depositCurrencyCommand(nil, fakePlayer, "jaku", 200)
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].currencyType).to.equal("jaku")
			expect(calls[1].amount).to.equal(200)
		end)

		it("surfaces the service's specific failure reason", function()
			nextResult = false
			nextReason = "insufficient jaku (100 < 250)"
			local message = depositCurrencyCommand(nil, fakePlayer, "jaku", 250)
			expect(message:find("insufficient", 1, true)).to.be.ok()
		end)
	end)
end
