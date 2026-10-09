local InputConstants = require(script.Parent.InputConstants)

return function()
	it("names gameplay as the base context and ui as a declared context", function()
		expect(InputConstants.BASE_CONTEXT).to.equal("gameplay")
		expect(InputConstants.isContext("gameplay")).to.equal(true)
		expect(InputConstants.isContext("ui")).to.equal(true)
		expect(InputConstants.isContext("nope")).to.equal(false)
	end)

	it("declares the default interact and sprint actions in the gameplay context", function()
		local interact = InputConstants.DEFAULT_ACTIONS.interact
		expect(interact).to.be.ok()
		expect(interact.context).to.equal("gameplay")
		expect(table.find(interact.bindings.keyboard, Enum.KeyCode.E)).to.be.ok()
		expect(table.find(interact.bindings.gamepad, Enum.KeyCode.ButtonX)).to.be.ok()
		local sprint = InputConstants.DEFAULT_ACTIONS.sprint
		expect(sprint).to.be.ok()
		expect(table.find(sprint.bindings.keyboard, Enum.KeyCode.LeftShift)).to.be.ok()
	end)

	it("freezes its tables", function()
		expect(table.isfrozen(InputConstants.CONTEXTS)).to.equal(true)
		expect(table.isfrozen(InputConstants.DEFAULT_ACTIONS)).to.equal(true)
	end)
end
