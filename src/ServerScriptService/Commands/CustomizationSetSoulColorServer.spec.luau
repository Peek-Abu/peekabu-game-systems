--!strict
--[=[
	Unit tests for the SetSoulColor Cmdr command implementation.
	Mock strategy: patch CustomizationService.setSoulColor inside beforeAll/afterAll (see
	AddCurrencyServer.spec for the rationale). The logic worth covering here is hue JOINING: the
	command takes up to three hues and composes the multi-hue id the service stores.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)
local setSoulColorCommand = require(ServerScriptService.Commands.CustomizationSetSoulColorServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("CustomizationSetSoulColorServer", function()
		local _origSet
		local calls: { { userId: number, colorId: string? } } = {}
		local nextResult = true
		local nextReason: string? = nil

		beforeAll(function()
			_origSet = CustomizationService.setSoulColor
			CustomizationService.setSoulColor = function(_self: any, userId: number, colorId: string?)
				table.insert(calls, { userId = userId, colorId = colorId })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			CustomizationService.setSoulColor = _origSet
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
			nextReason = nil
		end)

		it("forwards a single hue as-is", function()
			setSoulColorCommand(nil, fakePlayer, "blue", "-", "-")
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].colorId).to.equal("blue")
		end)

		it("joins supplied hues into one multi-hue id", function()
			setSoulColorCommand(nil, fakePlayer, "blue", "green", "-")
			expect(calls[1].colorId).to.equal("blue-green")
		end)

		it("preserves hue ORDER, since it decides the gradient direction", function()
			setSoulColorCommand(nil, fakePlayer, "green", "blue", "-")
			expect(calls[1].colorId).to.equal("green-blue")
		end)

		it("skips unsupplied slots rather than leaving empty segments", function()
			setSoulColorCommand(nil, fakePlayer, "blue", "-", "white")
			expect(calls[1].colorId).to.equal("blue-white")
		end)

		-- Joining no hues would produce "", which is not a registered id and would FAIL rather than
		-- clear — so the command has to pass the service the nil it documents for clearing.
		it("passes nil, not an empty string, when no hue is supplied at all", function()
			local message = setSoulColorCommand(nil, fakePlayer, "-", "-", "-")
			expect(calls[1].colorId).to.equal(nil)
			expect(message:find("Cleared", 1, true)).to.be.ok()
		end)

		it("surfaces the service's specific failure reason", function()
			nextResult = false
			nextReason = '"blue-blue-blue-blue" is not a registered soul colour'
			local message = setSoulColorCommand(nil, fakePlayer, "blue", "-", "-")
			expect(message:find("not a registered soul colour", 1, true)).to.be.ok()
		end)
	end)
end
