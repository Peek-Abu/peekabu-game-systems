--[[
	Unit tests for the cosmeticgrant command: CosmeticService.grant is patched (the TitleAwardServer.spec strategy).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticService = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local command = require(ServerScriptService.Commands.CosmeticGrantServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

return function()
	describe("CosmeticGrantServer", function()
		local original
		local calls = {}
		local result = { true, nil }

		beforeAll(function()
			original = CosmeticService.grant
			CosmeticService.grant = function(_self, userId, id)
				table.insert(calls, { userId = userId, id = id })
				return result[1], result[2]
			end
		end)

		afterAll(function()
			CosmeticService.grant = original
		end)

		beforeEach(function()
			calls = {}
			result = { true, nil }
		end)

		it("unlocks a registered item for the target and says so", function()
			local message = command(nil, fakePlayer, "Cappy.PJ")
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].id).to.equal("Cappy.PJ")
			expect(message:find("Unlocked", 1, true)).to.be.ok()
		end)

		it("passes the service's reason through", function()
			result = { false, "already owned" }
			expect(command(nil, fakePlayer, "Cappy"):find("already owned", 1, true)).to.be.ok()
		end)

		it("refuses unknown ids and single stickers without calling the service", function()
			command(nil, fakePlayer, "Nope")
			command(nil, fakePlayer, "CozyPack.Cocoa")
			expect(#calls).to.equal(0)
		end)
	end)
end
