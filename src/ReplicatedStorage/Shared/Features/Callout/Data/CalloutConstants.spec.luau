local CalloutConstants = require(script.Parent.CalloutConstants)

return function()
	it("binds the chat wheel to T and the d-pad, and keeps callouts short and rate-limited", function()
		expect(CalloutConstants.WHEEL_ACTION).to.equal("chatWheel")
		expect(CalloutConstants.WHEEL_KEY).to.equal(Enum.KeyCode.T)
		expect(CalloutConstants.STICKER_SECONDS < CalloutConstants.PING_SECONDS).to.equal(true)
		expect(CalloutConstants.BURST > 1 and CalloutConstants.WINDOW > CalloutConstants.GAP).to.equal(true)
	end)

	it("lifts a sticker clear of the head and lets it drift up less than that", function()
		expect(CalloutConstants.STICKER_LIFT > 0).to.equal(true)
		expect(CalloutConstants.STICKER_RISE >= 0).to.equal(true)
		expect(CalloutConstants.STICKER_RISE < CalloutConstants.STICKER_LIFT).to.equal(true)
		expect(CalloutConstants.STICKER_AHEAD > 0).to.equal(true)
	end)

	it("tosses with a registered clip, letting go of the sticker before the toss fades out", function()
		local AnimationRegistry =
			require(game:GetService("ReplicatedStorage").Shared.Features.Animation.Data.AnimationRegistry)
		expect(AnimationRegistry.get(CalloutConstants.TOSS_ANIMATION)).to.be.ok()
		expect(CalloutConstants.TOSS_FADE_IN > 0 and CalloutConstants.TOSS_FADE_OUT > 0).to.equal(true)
		expect(CalloutConstants.STICKER_RELEASE < CalloutConstants.TOSS_FADE_START).to.equal(true)
	end)

	it("lets the sticker leave the hand early in the toss and land well before it fades", function()
		expect(CalloutConstants.STICKER_RELEASE > 0 and CalloutConstants.STICKER_RELEASE < 0.5).to.equal(true)
		expect(CalloutConstants.STICKER_FLIGHT > 0).to.equal(true)
		expect(
			CalloutConstants.STICKER_RELEASE + CalloutConstants.STICKER_FLIGHT < CalloutConstants.STICKER_SECONDS / 2
		).to.equal(true)
	end)
end
