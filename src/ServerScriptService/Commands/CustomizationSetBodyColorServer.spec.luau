--!strict
--[=[
	Unit tests for the SetBodyColor Cmdr command implementation.
	Mock strategy: patch CustomizationService.setBodyColor inside beforeAll/afterAll (see
	AddCurrencyServer.spec for the rationale). Asserts the command builds a FREE rgb Color value — the
	palette-dye path belongs to the UI, not the admin command.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)
local setBodyColorCommand = require(ServerScriptService.Commands.CustomizationSetBodyColorServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("CustomizationSetBodyColorServer", function()
		local _origSet
		local calls: { { userId: number, channel: string, color: any } } = {}
		local nextResult = true
		local nextReason: string? = nil

		beforeAll(function()
			_origSet = CustomizationService.setBodyColor
			CustomizationService.setBodyColor = function(_self: any, userId: number, channel: string, color: any)
				table.insert(calls, { userId = userId, channel = channel, color = color })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			CustomizationService.setBodyColor = _origSet
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
			nextReason = nil
		end)

		it("forwards the channel and builds a free rgb Color", function()
			setBodyColorCommand(nil, fakePlayer, "skin", 200, 120, 90)
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].channel).to.equal("skin")
			expect(calls[1].color.source).to.equal("rgb")
			expect(calls[1].color.r).to.equal(200)
			expect(calls[1].color.g).to.equal(120)
			expect(calls[1].color.b).to.equal(90)
		end)

		it("returns a success message on success and a failure message otherwise", function()
			expect(setBodyColorCommand(nil, fakePlayer, "skin", 1, 2, 3):find("Set skin")).to.be.ok()
			nextResult = false
			expect(setBodyColorCommand(nil, fakePlayer, "skin", 1, 2, 3):find("Failed")).to.be.ok()
		end)

		it("surfaces the service's specific failure reason", function()
			nextResult = false
			nextReason = '"elbows" is not a registered body channel'
			local message = setBodyColorCommand(nil, fakePlayer, "elbows", 1, 2, 3)
			expect(message:find("not a registered body channel", 1, true)).to.be.ok()
		end)
	end)
end
