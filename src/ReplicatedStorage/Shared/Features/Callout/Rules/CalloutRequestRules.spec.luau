local CalloutRequestRules = require(script.Parent.CalloutRequestRules)

return function()
	it("round-trips a sticker slot and a ping spot", function()
		local sticker = CalloutRequestRules.parse(CalloutRequestRules.build({ kind = "sticker", slot = 2 }))
		expect(sticker.kind).to.equal("sticker")
		expect(sticker.slot).to.equal(2)
		local ping = CalloutRequestRules.parse(
			CalloutRequestRules.build({ kind = "ping", id = "gloom", at = Vector3.new(1, 2, 3) })
		)
		expect(ping.id).to.equal("gloom")
		expect(ping.at).to.equal(Vector3.new(1, 2, 3))
	end)

	it("drops anything malformed", function()
		for _, bad in
			{
				"x",
				{},
				{ kind = "sticker", slot = 5 },
				{ kind = "sticker", slot = 1.5 },
				{ kind = "ping", id = "gloom", x = 0, y = 0 },
				{ kind = "ping", id = "gloom", x = 0 / 0, y = 0, z = 0 },
				{ kind = "ping", id = 4, x = 0, y = 0, z = 0 },
				{ kind = "shout" },
			}
		do
			local request, reason = CalloutRequestRules.parse(bad)
			expect(request).never.to.be.ok()
			expect(reason).to.be.a("string")
		end
	end)

	it("reads a Shown packet back, with a spot only for a ping", function()
		local ping = CalloutRequestRules.shown({ userId = 1, kind = "ping", id = "help", x = 1, y = 2, z = 3 })
		expect(ping.at).to.equal(Vector3.new(1, 2, 3))
		local sticker =
			CalloutRequestRules.shown({ userId = 1, kind = "sticker", id = "CozyPack.Cocoa", x = 0, y = 0, z = 0 })
		expect(sticker.at).never.to.be.ok()
		expect(CalloutRequestRules.shown({ userId = 1, kind = "nope", id = "x", x = 0, y = 0, z = 0 })).never.to.be.ok()
	end)
end
