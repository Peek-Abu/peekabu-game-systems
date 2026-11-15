local UIGamepadStore = require(script.Parent.UIGamepadStore)

return function()
	afterEach(function()
		UIGamepadStore.reset()
	end)

	it("starts off and follows the last input", function()
		expect(UIGamepadStore.active()).to.equal(false)
		UIGamepadStore.setInput(Enum.UserInputType.Gamepad1)
		expect(UIGamepadStore.active()).to.equal(true)
		UIGamepadStore.setInput(Enum.UserInputType.MouseMovement)
		expect(UIGamepadStore.active()).to.equal(false)
	end)

	it("keeps gamepad on while the stick or a button keeps coming in", function()
		UIGamepadStore.setInput(Enum.UserInputType.Gamepad2)
		UIGamepadStore.setInput(Enum.UserInputType.Gamepad2)
		expect(UIGamepadStore.active()).to.equal(true)
	end)

	it("ignores window focus and none, which say nothing about the device", function()
		UIGamepadStore.setInput(Enum.UserInputType.Gamepad1)
		UIGamepadStore.setInput(Enum.UserInputType.Focus)
		UIGamepadStore.setInput(Enum.UserInputType.None)
		expect(UIGamepadStore.active()).to.equal(true)
	end)
end
