local ToonCoveredContext = require(script.Parent.ToonCoveredContext)

return function()
	it("is a React context, uncovered by default (a screen outside SceneHost draws as before)", function()
		expect(ToonCoveredContext.Context).to.be.ok()
		expect(ToonCoveredContext.DEFAULT).to.equal(false)
	end)
end
