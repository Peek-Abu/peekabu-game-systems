local EmployeeSkinRegistry = require(script.Parent.EmployeeSkinRegistry)

return function()
	describe("skinFor", function()
		it("gives the owner (icemonkey1) the OwnerSpecial skin", function()
			expect(EmployeeSkinRegistry.skinFor(20661908)).to.equal("OwnerSpecial")
		end)

		it("gives everyone else nothing (the employee's default skin)", function()
			expect(EmployeeSkinRegistry.skinFor(1)).never.to.be.ok()
			expect(EmployeeSkinRegistry.skinFor(-1)).never.to.be.ok()
		end)
	end)
end
