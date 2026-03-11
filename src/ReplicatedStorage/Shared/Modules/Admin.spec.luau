--!strict
--[=[
	Unit tests for the Admin module.

	These run in Studio (TestEZ via TestRunner), where `Admin.isAdmin` returns true for ANY player by
	design (Studio-always-allowed). So the meaningful assertions here are the module's shape and that
	the Studio bypass holds; the allowlist branch is only reachable in a published server and is not
	exercised here.
]=]
local Admin = require(script.Parent.Admin)

return function()
	describe("Admin", function()
		it("should expose isAdmin", function()
			expect(Admin.isAdmin).to.be.a("function")
		end)

		it("should allow any player in Studio (Studio bypass)", function()
			-- A stand-in with just the field isAdmin reads. In Studio the UserId is never consulted.
			local fakePlayer = { UserId = -1 } :: any
			expect(Admin.isAdmin(fakePlayer)).to.equal(true)
		end)
	end)
end
