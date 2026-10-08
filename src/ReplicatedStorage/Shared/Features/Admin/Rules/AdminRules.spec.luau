--!strict
--[=[
	Unit tests for the AdminRules module.

	These assert against the pure `AdminRules.isAdminForSession(userId, isStudio, allowlist?)` core so they
	are deterministic in ANY runtime — the suite runs in Open Cloud (not Studio), where
	`RunService:IsStudio()` is false, so a test that called `isAdmin` and expected the Studio bypass
	would pass in Studio but fail in CI. Driving the pure core covers both the Studio-bypass branch and
	the allowlist branch without depending on the runtime or the live admin list.
]=]
local AdminRules = require(script.Parent.AdminRules)

return function()
	describe("Admin", function()
		it("should expose isAdmin", function()
			expect(AdminRules.isAdmin).to.be.a("function")
		end)

		describe("isAdminForSession (pure core, runtime-independent)", function()
			it("allows ANY userId when the session is Studio (Studio bypass)", function()
				expect(AdminRules.isAdminForSession(-1, true)).to.equal(true)
			end)

			it("in a published server, allows a userId in the allowlist", function()
				expect(AdminRules.isAdminForSession(7, false, { [7] = true })).to.equal(true)
			end)

			it("in a published server, denies a userId not in the allowlist", function()
				expect(AdminRules.isAdminForSession(8, false, { [7] = true })).to.equal(false)
			end)
		end)
	end)
end
