--!strict
--[=[
	Unit tests for the DepositItem Cmdr command implementation. Mock strategy: patch
	BankService.depositItem in beforeAll/afterAll (see RemoveItemServer.spec for the rationale).
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BankService = require(ServerScriptService.Features.Bank.BankServiceServer)
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)
local depositItemCommand = require(ServerScriptService.Commands.BankDepositItemServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("BankDepositItemServer", function()
		local _orig
		local calls: { { userId: number, spec: any } } = {}
		local nextResult = true
		local nextReason: string? = nil

		beforeAll(function()
			ItemContentRegistry.init()
			_orig = BankService.depositItem
			BankService.depositItem = function(_self: any, userId: number, spec: any)
				table.insert(calls, { userId = userId, spec = spec })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			BankService.depositItem = _orig
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
			nextReason = nil
		end)

		it("forwards a stackable itemType as an { itemType } spec", function()
			depositItemCommand(nil, fakePlayer, "wood")
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].spec.itemType).to.equal("wood")
			expect(calls[1].spec.uid).to.equal(nil)
		end)

		it(
			"forwards a registered UNIQUE itemType as an { itemType } spec (service gives the by-uid refusal)",
			function()
				-- Routing a unique itemType to { uid } would surface a cryptic "no item with uid" instead.
				depositItemCommand(nil, fakePlayer, "phoenix-blade")
				expect(calls[1].spec.itemType).to.equal("phoenix-blade")
				expect(calls[1].spec.uid).to.equal(nil)
			end
		)

		it("forwards a non-itemType string as a { uid } spec", function()
			depositItemCommand(nil, fakePlayer, "42_7")
			expect(calls[1].spec.uid).to.equal("42_7")
			expect(calls[1].spec.itemType).to.equal(nil)
		end)

		it("surfaces the service's specific failure reason", function()
			nextResult = false
			nextReason = "bank holds 90 entries, exceeding CAPACITY (90)"
			local message = depositItemCommand(nil, fakePlayer, "wood")
			expect(message:find("CAPACITY", 1, true)).to.be.ok()
		end)
	end)
end
