--!strict
--[=[
	Unit tests for the WithdrawCurrency Cmdr command implementation. Mirrors DepositCurrencyServer.spec:
	patch BankService.withdrawCurrency.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local BankService = require(ServerScriptService.Features.Bank.BankServiceServer)
local withdrawCurrencyCommand = require(ServerScriptService.Commands.BankWithdrawCurrencyServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("BankWithdrawCurrencyServer", function()
		local _orig
		local calls: { { userId: number, currencyType: string, amount: number } } = {}
		local nextResult = true
		local nextReason: string? = nil

		beforeAll(function()
			_orig = BankService.withdrawCurrency
			BankService.withdrawCurrency = function(_self: any, userId: number, currencyType: any, amount: number)
				table.insert(calls, { userId = userId, currencyType = currencyType, amount = amount })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			BankService.withdrawCurrency = _orig
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
			nextReason = nil
		end)

		it("forwards the target's UserId, currency type, and amount", function()
			withdrawCurrencyCommand(nil, fakePlayer, "jaku", 150)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].currencyType).to.equal("jaku")
			expect(calls[1].amount).to.equal(150)
		end)

		it("surfaces the service's specific failure reason", function()
			nextResult = false
			nextReason = "insufficient jaku (50 < 150)"
			local message = withdrawCurrencyCommand(nil, fakePlayer, "jaku", 150)
			expect(message:find("insufficient", 1, true)).to.be.ok()
		end)
	end)
end
