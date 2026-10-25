local EmoteConstants = require(script.Parent.EmoteConstants)

return function()
	it("binds the wheel to B and a shoulder button, with a short pause between emotes", function()
		expect(EmoteConstants.WHEEL_ACTION).to.equal("emoteWheel")
		expect(EmoteConstants.WHEEL_KEY).to.equal(Enum.KeyCode.B)
		expect(EmoteConstants.WHEEL_GAMEPAD).to.equal(Enum.KeyCode.ButtonL1)
		expect(EmoteConstants.COOLDOWN > 0 and EmoteConstants.COOLDOWN <= 3).to.equal(true)
	end)
end
