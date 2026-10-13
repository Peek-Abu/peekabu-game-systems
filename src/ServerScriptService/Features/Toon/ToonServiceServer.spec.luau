local ToonServiceServer = require(script.Parent.ToonServiceServer)

return function()
	describe("ToonServiceServer", function()
		it("depends on the services whose state drives the expression", function()
			for _, name in
				{ "OccupantServiceServer", "VacuumServiceServer", "CarryServiceServer", "CargoServiceServer" }
			do
				expect(table.find(ToonServiceServer.dependencies, name)).to.be.ok()
			end
		end)

		it("exposes the lifecycle and a debugger snapshot", function()
			expect(ToonServiceServer.init).to.be.a("function")
			expect(ToonServiceServer.start).to.be.a("function")
			expect(ToonServiceServer.stop).to.be.a("function")
			local state = ToonServiceServer:getState()
			expect(state.toon).to.be.a("string")
			expect(state.installed).to.be.a("boolean")
		end)
	end)
end
