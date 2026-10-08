--!strict
--[=[
	Unit tests for the SetHeadType Cmdr command implementation.
	Mock strategy: patch CustomizationService.setHeadType inside beforeAll/afterAll (see
	AddCurrencyServer.spec for the rationale).
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)
local setHeadTypeCommand = require(ServerScriptService.Commands.CustomizationSetHeadTypeServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("CustomizationSetHeadTypeServer", function()
		local _origSet
		local calls: { { userId: number, headType: string } } = {}
		local nextResult = true
		local nextReason: string? = nil

		beforeAll(function()
			_origSet = CustomizationService.setHeadType
			CustomizationService.setHeadType = function(_self: any, userId: number, headType: string)
				table.insert(calls, { userId = userId, headType = headType })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			CustomizationService.setHeadType = _origSet
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
			nextReason = nil
		end)

		it("forwards the target's UserId and the head type", function()
			setHeadTypeCommand(nil, fakePlayer, "Covered")
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].headType).to.equal("Covered")
		end)

		it("returns a success message on success and a failure message otherwise", function()
			expect(setHeadTypeCommand(nil, fakePlayer, "Covered"):find("Set")).to.be.ok()
			nextResult = false
			expect(setHeadTypeCommand(nil, fakePlayer, "Covered"):find("Failed")).to.be.ok()
		end)

		it("surfaces the service's specific failure reason", function()
			nextResult = false
			nextReason = '"Partial" is not a registered head type'
			local message = setHeadTypeCommand(nil, fakePlayer, "Partial")
			expect(message:find("not a registered head type", 1, true)).to.be.ok()
		end)
	end)
end
