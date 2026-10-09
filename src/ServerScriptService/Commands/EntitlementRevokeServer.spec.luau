--[[
	Unit tests for the entitlementrevoke Cmdr command (see EntitlementGrantServer.spec for the mock strategy).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local EntitlementService = require(ServerScriptService.Features.Entitlement.EntitlementServiceServer)
local revokeCommand = require(ServerScriptService.Commands.EntitlementRevokeServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

return function()
	describe("EntitlementRevokeServer", function()
		local originalRevoke
		local owned = { ["spec-cmd/cape"] = true }

		beforeAll(function()
			originalRevoke = EntitlementService.revoke
			EntitlementService.revoke = function(_self, _userId, category, id)
				local key = `{category}/{id}`
				if not owned[key] then
					return false, "not owned"
				end
				owned[key] = nil
				return true
			end
		end)

		afterAll(function()
			EntitlementService.revoke = originalRevoke
		end)

		it("revokes an owned entitlement", function()
			expect(revokeCommand(nil, fakePlayer, "spec-cmd", "cape"):find("Revoked")).to.be.ok()
			expect(owned["spec-cmd/cape"]).to.equal(nil)
		end)

		it("reports when it was not owned", function()
			expect(revokeCommand(nil, fakePlayer, "spec-cmd", "cape"):find("not owned")).to.be.ok()
		end)
	end)
end
