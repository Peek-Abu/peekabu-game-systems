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

	it("reads a Shown packet back: a ping's spot, a sticker's spot only when it was placed", function()
		local ping =
			CalloutRequestRules.shown({ userId = 1, kind = "ping", id = "help", x = 1, y = 2, z = 3, placed = true })
		expect(ping.at).to.equal(Vector3.new(1, 2, 3))
		local placed = CalloutRequestRules.shown({
			userId = 1,
			kind = "sticker",
			id = "CozyPack.CocoaBreak",
			x = 4,
			y = 5,
			z = 6,
			placed = true,
		})
		expect(placed.at).to.equal(Vector3.new(4, 5, 6))
		local bodiless = CalloutRequestRules.shown({
			userId = 1,
			kind = "sticker",
			id = "CozyPack.CocoaBreak",
			x = 0,
			y = 0,
			z = 0,
			placed = false,
		})
		expect(bodiless.at).never.to.be.ok()
		expect(CalloutRequestRules.shown({ userId = 1, kind = "nope", id = "x", x = 0, y = 0, z = 0, placed = false })).never.to.be.ok()
	end)

	it("packs a Shown for the wire and reads it back the same", function()
		local sticker = { userId = 3, kind = "sticker", id = "BubblePack.Yay", at = Vector3.new(1, 2, 3) }
		local back = CalloutRequestRules.shown(CalloutRequestRules.shownPacket(sticker))
		expect(back.at).to.equal(Vector3.new(1, 2, 3))
		expect(back.id).to.equal("BubblePack.Yay")
		local bodiless = CalloutRequestRules.shownPacket({ userId = 3, kind = "sticker", id = "BubblePack.Yay" })
		expect(bodiless.placed).to.equal(false)
		expect(CalloutRequestRules.shown(bodiless).at).never.to.be.ok()
	end)
end
