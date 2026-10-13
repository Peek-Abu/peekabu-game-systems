local ToonServiceClient = require(script.Parent.ToonServiceClient)

return function()
	describe("ToonServiceClient", function()
		it("exposes the lifecycle and a debugger snapshot", function()
			expect(ToonServiceClient.start).to.be.a("function")
			expect(ToonServiceClient.stop).to.be.a("function")
			local state = ToonServiceClient:getState()
			expect(state.faces).to.be.a("number")
			expect(state.ears).to.be.a("table")
		end)
	end)
end
