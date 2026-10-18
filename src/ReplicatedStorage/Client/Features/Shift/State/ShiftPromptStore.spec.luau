local ShiftPromptStore = require(script.Parent.ShiftPromptStore)

local function view(id, kind)
	return { id = id, action = "Load", object = "Truck", key = "E", hold = 0, kind = kind }
end

return function()
	afterEach(function()
		ShiftPromptStore.clear()
	end)

	it("shows the latest prompt", function()
		ShiftPromptStore.show(view(1, "cargo-load"))
		ShiftPromptStore.show(view(2, "shift-clockout"))
		expect(ShiftPromptStore.shown().id).to.equal(2)
	end)

	it("hides only the prompt that is shown", function()
		ShiftPromptStore.show(view(2))
		ShiftPromptStore.hide(1)
		expect(ShiftPromptStore.shown().id).to.equal(2)
		ShiftPromptStore.hide(2)
		expect(ShiftPromptStore.shown()).to.equal(nil)
	end)

	it("records when a hold began and forgets it when it ends", function()
		ShiftPromptStore.show(view(3))
		ShiftPromptStore.holdBegan(3, 10)
		expect(ShiftPromptStore.shown().holdStartedAt).to.equal(10)
		ShiftPromptStore.holdEnded(3)
		expect(ShiftPromptStore.shown().holdStartedAt).to.equal(nil)
	end)

	it("ignores a hold on a prompt that is not shown", function()
		ShiftPromptStore.show(view(3))
		ShiftPromptStore.holdBegan(4, 10)
		expect(ShiftPromptStore.shown().holdStartedAt).to.equal(nil)
	end)
end
