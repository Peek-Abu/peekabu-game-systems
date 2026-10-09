--!strict
--[[
	Unit tests for the TitleEquip Cmdr command implementation (mock strategy per AddCurrencyServer.spec).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local TitlesService = require(ServerScriptService.Features.Title.TitleServiceServer)
local titleEquipCommand = require(ServerScriptService.Commands.TitleEquipServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("TitleEquipServer", function()
		local _origEquip
		local calls: { { userId: number, titleId: string } } = {}
		local failResult: boolean? = nil
		local failReason: string? = nil

		beforeAll(function()
			_origEquip = TitlesService.equip
			TitlesService.equip = function(_self: any, userId: number, titleId: string): (boolean, string?)
				table.insert(calls, { userId = userId, titleId = titleId })
				if failResult ~= nil then
					return failResult, failReason
				end
				return true
			end
		end)

		afterAll(function()
			TitlesService.equip = _origEquip
		end)

		beforeEach(function()
			calls = {}
			failResult = nil
			failReason = nil
		end)

		it("forwards the target's UserId and the title id to the service", function()
			titleEquipCommand(nil, fakePlayer, "veteran")
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].titleId).to.equal("veteran")
		end)

		it("reports success naming the title and the player", function()
			local message = titleEquipCommand(nil, fakePlayer, "veteran")
			expect(message:find("Equipped")).to.be.ok()
			expect(message:find("veteran")).to.be.ok()
			expect(message:find("TestPlayer")).to.be.ok()
		end)

		it("reports the service's failure reason", function()
			failResult = false
			failReason = "not earned — it cannot be equipped"
			local message = titleEquipCommand(nil, fakePlayer, "veteran")
			expect(message:find("Failed")).to.be.ok()
			expect(message:find("cannot be equipped")).to.be.ok()
		end)
	end)
end
