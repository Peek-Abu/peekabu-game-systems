local EmployeeServiceServer = require(script.Parent.EmployeeServiceServer)

return function()
	describe("EmployeeServiceServer", function()
		it("depends on the services whose state drives the expression", function()
			for _, name in
				{ "OccupantServiceServer", "VacuumServiceServer", "CarryServiceServer", "CargoServiceServer" }
			do
				expect(table.find(EmployeeServiceServer.dependencies, name)).to.be.ok()
			end
		end)

		it("depends on Rank, whose level colours the uniform's lanyard", function()
			expect(table.find(EmployeeServiceServer.dependencies, "RankServiceServer")).to.be.ok()
		end)

		it("exposes the lifecycle and a debugger snapshot", function()
			expect(EmployeeServiceServer.init).to.be.a("function")
			expect(EmployeeServiceServer.start).to.be.a("function")
			expect(EmployeeServiceServer.stop).to.be.a("function")
			local state = EmployeeServiceServer:getState()
			expect(state.employee).to.be.a("string")
			expect(state.installed).to.be.a("boolean")
			expect(state.skinned).to.be.a("number")
			expect(state.uniformed).to.be.a("number")
		end)
	end)
end
