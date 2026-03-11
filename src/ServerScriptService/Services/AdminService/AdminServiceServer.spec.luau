--!strict
local AdminServiceServer = require(script.Parent.AdminServiceServer)

return function()
	describe("AdminServiceServer", function()
		it("should have correct dependencies", function()
			expect(AdminServiceServer.dependencies).to.be.a("table")
			expect(#AdminServiceServer.dependencies).to.equal(0)
		end)

		it("should implement lifecycle methods", function()
			expect(AdminServiceServer.init).to.be.a("function")
			expect(AdminServiceServer.start).to.be.a("function")
		end)
	end)
end
