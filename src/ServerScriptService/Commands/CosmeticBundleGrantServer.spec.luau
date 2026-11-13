--[[
	Unit tests for the bundlegrant command: CosmeticService.grantBundle is patched (the CosmeticGrantServer.spec strategy).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticService = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local command = require(ServerScriptService.Commands.CosmeticBundleGrantServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

return function()
	describe("CosmeticBundleGrantServer", function()
		local original
		local calls = {}
		local result = { true, nil }

		beforeAll(function()
			original = CosmeticService.grantBundle
			CosmeticService.grantBundle = function(_self, userId, id)
				table.insert(calls, { userId = userId, id = id })
				return result[1], result[2]
			end
		end)

		afterAll(function()
			CosmeticService.grantBundle = original
		end)

		beforeEach(function()
			calls = {}
			result = { true, nil }
		end)

		it("unlocks the bundle for the target and says so", function()
			local message = command(nil, fakePlayer, "Bundle.PJCappy")
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].id).to.equal("Bundle.PJCappy")
			expect(message:find("Unlocked bundle", 1, true)).to.be.ok()
		end)

		it("passes the service's reason through", function()
			result = { false, "unknown bundle" }
			expect(command(nil, fakePlayer, "Bundle.Nope"):find("unknown bundle", 1, true)).to.be.ok()
		end)
	end)
end
