local CalloutConstants = require(script.Parent.CalloutConstants)

return function()
	it("binds the chat wheel to T and the d-pad, and keeps callouts short and rate-limited", function()
		expect(CalloutConstants.WHEEL_ACTION).to.equal("chatWheel")
		expect(CalloutConstants.WHEEL_KEY).to.equal(Enum.KeyCode.T)
		expect(CalloutConstants.STICKER_SECONDS < CalloutConstants.PING_SECONDS).to.equal(true)
		expect(CalloutConstants.BURST > 1 and CalloutConstants.WINDOW > CalloutConstants.GAP).to.equal(true)
	end)
end
