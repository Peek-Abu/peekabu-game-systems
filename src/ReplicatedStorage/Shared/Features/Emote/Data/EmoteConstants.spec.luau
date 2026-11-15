local EmoteConstants = require(script.Parent.EmoteConstants)
local HideConstants = require(script.Parent.Parent.Parent.Hide.Data.HideConstants)

return function()
	it("binds the wheel to B and a shoulder button, with a short pause between emotes", function()
		expect(EmoteConstants.WHEEL_ACTION).to.equal("emoteWheel")
		expect(EmoteConstants.WHEEL_KEY).to.equal(Enum.KeyCode.B)
		expect(EmoteConstants.WHEEL_GAMEPAD).to.equal(Enum.KeyCode.ButtonL2)
		expect(EmoteConstants.COOLDOWN > 0 and EmoteConstants.COOLDOWN <= 3).to.equal(true)
	end)

	it("never shares its gamepad button with hiding (emotes work in shifts, beside hiding spots)", function()
		-- L1 opened the wheel AND held the hiding spot's prompt at once (P1 device check, 11-14).
		expect(EmoteConstants.WHEEL_GAMEPAD).never.to.equal(HideConstants.GAMEPAD_KEY)
		expect(EmoteConstants.WHEEL_GAMEPAD).never.to.equal(HideConstants.JUMP_OUT_GAMEPAD_KEY)
	end)
end
