--!strict
--[=[
	Unit tests for the WithdrawItem Cmdr command implementation. Mock strategy mirrors
	DepositItemServer.spec: patch BankService.withdrawItem.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BankService = require(ServerScriptService.Features.Bank.BankServiceServer)
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)
local withdrawItemCommand = require(ServerScriptService.Commands.BankWithdrawItemServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("BankWithdrawItemServer", function()
		local _orig
		local calls: { { userId: number, spec: any } } = {}
		local nextResult = true
		local nextReason: string? = nil

		beforeAll(function()
			ItemContentRegistry.init()
			_orig = BankService.withdrawItem
			BankService.withdrawItem = function(_self: any, userId: number, spec: any)
				table.insert(calls, { userId = userId, spec = spec })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			BankService.withdrawItem = _orig
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
			nextReason = nil
		end)

		it("forwards a stackable itemType as an { itemType } spec", function()
			withdrawItemCommand(nil, fakePlayer, "wood")
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].spec.itemType).to.equal("wood")
		end)

		it(
			"forwards a registered UNIQUE itemType as an { itemType } spec (service gives the by-uid refusal)",
			function()
				withdrawItemCommand(nil, fakePlayer, "phoenix-blade")
				expect(calls[1].spec.itemType).to.equal("phoenix-blade")
				expect(calls[1].spec.uid).to.equal(nil)
			end
		)

		it("forwards a uid string as a { uid } spec", function()
			withdrawItemCommand(nil, fakePlayer, "42_7")
			expect(calls[1].spec.uid).to.equal("42_7")
		end)

		it("surfaces the service's specific failure reason", function()
			nextResult = false
			nextReason = 'kind "weapon" entry count 31 exceeds KIND_CAPS (30)'
			local message = withdrawItemCommand(nil, fakePlayer, "42_7")
			expect(message:find("KIND_CAPS", 1, true)).to.be.ok()
		end)
	end)
end
