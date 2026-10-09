--!strict
--[[
	Unit tests for the TitleAward Cmdr command implementation. Mock strategy per AddCurrencyServer.spec:
	patch TitlesService.award, record the call, and assert the formatted reply. The command only
	touches UserId/Name, so a shaped fake Player suffices.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local TitlesService = require(ServerScriptService.Features.Title.TitleServiceServer)
local titleAwardCommand = require(ServerScriptService.Commands.TitleAwardServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("TitleAwardServer", function()
		local _origAward
		local calls: { { userId: number, titleId: string } } = {}
		local failResult: boolean? = nil
		local failReason: string? = nil

		beforeAll(function()
			_origAward = TitlesService.award
			TitlesService.award = function(_self: any, userId: number, titleId: string): (boolean, string?)
				table.insert(calls, { userId = userId, titleId = titleId })
				if failResult ~= nil then
					return failResult, failReason
				end
				return true
			end
		end)

		afterAll(function()
			TitlesService.award = _origAward
		end)

		beforeEach(function()
			calls = {}
			failResult = nil
			failReason = nil
		end)

		it("forwards the target's UserId and the title id to the service", function()
			titleAwardCommand(nil, fakePlayer, "veteran")
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].titleId).to.equal("veteran")
		end)

		it("reports success naming the title and the player", function()
			local message = titleAwardCommand(nil, fakePlayer, "veteran")
			expect(message:find("Awarded")).to.be.ok()
			expect(message:find("veteran")).to.be.ok()
			expect(message:find("TestPlayer")).to.be.ok()
		end)

		it("reports the service's failure reason", function()
			failResult = false
			failReason = "already awarded"
			local message = titleAwardCommand(nil, fakePlayer, "veteran")
			expect(message:find("Failed")).to.be.ok()
			expect(message:find("already awarded")).to.be.ok()
		end)
	end)
end
