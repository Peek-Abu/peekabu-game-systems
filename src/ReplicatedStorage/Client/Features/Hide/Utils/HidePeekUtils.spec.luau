local HidePeekUtils = require(script.Parent.HidePeekUtils)

return function()
	describe("peekMode", function()
		it("is a custom camera mode with an update", function()
			local mode = HidePeekUtils.peekMode(CFrame.new(1, 2, 3))
			expect(mode.kind).to.equal("custom")
			expect(type(mode.update)).to.equal("function")
		end)
	end)
end
