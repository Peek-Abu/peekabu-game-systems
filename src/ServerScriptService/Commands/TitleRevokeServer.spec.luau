--!strict
--[[
	Unit tests for the TitleRevoke Cmdr command implementation (mock strategy per AddCurrencyServer.spec).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local TitlesService = require(ServerScriptService.Features.Title.TitleServiceServer)
local titleRevokeCommand = require(ServerScriptService.Commands.TitleRevokeServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("TitleRevokeServer", function()
		local _origRevoke
		local calls: { { userId: number, titleId: string } } = {}
		local failResult: boolean? = nil
		local failReason: string? = nil

		beforeAll(function()
			_origRevoke = TitlesService.revoke
			TitlesService.revoke = function(_self: any, userId: number, titleId: string): (boolean, string?)
				table.insert(calls, { userId = userId, titleId = titleId })
				if failResult ~= nil then
					return failResult, failReason
				end
				return true
			end
		end)

		afterAll(function()
			TitlesService.revoke = _origRevoke
		end)

		beforeEach(function()
			calls = {}
			failResult = nil
			failReason = nil
		end)

		it("forwards the target's UserId and the title id to the service", function()
			titleRevokeCommand(nil, fakePlayer, "veteran")
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].titleId).to.equal("veteran")
		end)

		it("reports success naming the title and the player", function()
			local message = titleRevokeCommand(nil, fakePlayer, "veteran")
			expect(message:find("Revoked")).to.be.ok()
			expect(message:find("veteran")).to.be.ok()
			expect(message:find("TestPlayer")).to.be.ok()
		end)

		it("reports the service's failure reason", function()
			failResult = false
			failReason = "not earned"
			local message = titleRevokeCommand(nil, fakePlayer, "veteran")
			expect(message:find("Failed")).to.be.ok()
			expect(message:find("not earned")).to.be.ok()
		end)
	end)
end
