local EmployeeServiceClient = require(script.Parent.EmployeeServiceClient)

return function()
	describe("EmployeeServiceClient", function()
		it("exposes the lifecycle and a debugger snapshot", function()
			expect(EmployeeServiceClient.start).to.be.a("function")
			expect(EmployeeServiceClient.stop).to.be.a("function")
			local state = EmployeeServiceClient:getState()
			expect(state.faces).to.be.a("number")
			expect(state.ears).to.be.a("table")
		end)
	end)
end
