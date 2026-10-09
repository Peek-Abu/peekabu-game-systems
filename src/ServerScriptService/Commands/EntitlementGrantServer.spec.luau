--[[
	Unit tests for the entitlementgrant / entitlementrevoke Cmdr commands. Mock strategy (the
	CurrencyAddServer.spec convention): patch EntitlementService.grant / revoke inside beforeAll/afterAll.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EntitlementRegistry = require(ReplicatedStorage.Shared.Features.Entitlement.Data.EntitlementRegistry)
local EntitlementService = require(ServerScriptService.Features.Entitlement.EntitlementServiceServer)
local grantCommand = require(ServerScriptService.Commands.EntitlementGrantServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

return function()
	describe("EntitlementGrantServer", function()
		local originalGrant
		local owned = {}

		beforeAll(function()
			if not EntitlementRegistry.has("spec-cmd", "cape") then
				EntitlementRegistry.register("spec-cmd", "cape", { name = "Cape" })
			end
			originalGrant = EntitlementService.grant
			EntitlementService.grant = function(_self, _userId, category, id)
				local key = `{category}/{id}`
				if owned[key] then
					return false, "already owned"
				end
				owned[key] = true
				return true
			end
		end)

		afterAll(function()
			EntitlementService.grant = originalGrant
		end)

		it("grants a registered entitlement", function()
			local message = grantCommand(nil, fakePlayer, "spec-cmd", "cape")
			expect(owned["spec-cmd/cape"]).to.equal(true)
			expect(message:find("Granted")).to.be.ok()
		end)

		it("reports a refusal with its reason", function()
			expect(grantCommand(nil, fakePlayer, "spec-cmd", "cape"):find("already owned")).to.be.ok()
		end)

		it("refuses an unregistered entitlement without calling the service", function()
			local message = grantCommand(nil, fakePlayer, "spec-cmd", "nope")
			expect(message:find("not a registered")).to.be.ok()
			expect(owned["spec-cmd/nope"]).to.equal(nil)
		end)
	end)
end
