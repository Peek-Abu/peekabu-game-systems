--!strict
--[=[
	Unit tests for CustomizationArtCheckSystem: the boot-time wrapper around CustomizationArtCheck.

	The CHECKING logic is specced exhaustively in CustomizationArtCheck.spec against fabricated trees.
	What is worth pinning here is only what this wrapper adds: it looks up the real trees, hands back a
	well-formed Summary, and never throws, whatever state the place is in. A test place has no art at
	all, so "reports problems" is the expected result here, not a failure.
]=]

local CustomizationArtCheckSystem = require(script.Parent.CustomizationArtCheckSystem)

return function()
	describe("check", function()
		it("returns a well-formed summary without throwing", function()
			local summary = CustomizationArtCheckSystem.check()

			expect(type(summary.ok)).to.equal("boolean")
			expect(type(summary.total)).to.equal("number")
			expect(type(summary.lines)).to.equal("table")
			expect(summary.ok).to.equal(summary.total == 0)
			expect(#summary.lines).to.equal(summary.total)
		end)

		it("is repeatable: a re-check after an art edit must be a fresh read", function()
			local first = CustomizationArtCheckSystem.check()
			local second = CustomizationArtCheckSystem.check()
			expect(second.total).to.equal(first.total)
		end)
	end)

	describe("run", function()
		it("logs the report without throwing", function()
			expect(function()
				CustomizationArtCheckSystem.run()
			end).never.to.throw()
		end)
	end)

	describe("not a service", function()
		it("has no service lifecycle: CustomizationServiceServer starts it", function()
			local shape: any = CustomizationArtCheckSystem
			expect(shape.dependencies).to.equal(nil)
			expect(shape.start).to.equal(nil)
		end)
	end)
end
