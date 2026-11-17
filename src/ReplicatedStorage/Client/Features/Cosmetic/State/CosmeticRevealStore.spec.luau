local CosmeticRevealStore = require(script.Parent.CosmeticRevealStore)

return function()
	afterEach(function()
		CosmeticRevealStore.reset()
	end)

	it("shows the first reveal at once and queues the rest in order", function()
		CosmeticRevealStore.push({ ids = { "A" }, source = "shop" })
		CosmeticRevealStore.push({ ids = { "B" }, source = "grant" })
		expect(CosmeticRevealStore.current().ids[1]).to.equal("A")
		CosmeticRevealStore.next()
		expect(CosmeticRevealStore.current().ids[1]).to.equal("B")
		CosmeticRevealStore.next()
		expect(CosmeticRevealStore.current()).to.equal(nil)
	end)

	it("keeps at most MAX_QUEUED waiting (the oldest waiting one goes)", function()
		CosmeticRevealStore.push({ ids = { "shown" }, source = "shop" })
		for index = 1, CosmeticRevealStore.MAX_QUEUED + 2 do
			CosmeticRevealStore.push({ ids = { `w{index}` }, source = "shop" })
		end
		CosmeticRevealStore.next()
		expect(CosmeticRevealStore.current().ids[1]).to.equal("w3")
	end)

	it("ignores an empty grant", function()
		CosmeticRevealStore.push({ ids = {}, source = "shop" })
		expect(CosmeticRevealStore.current()).to.equal(nil)
	end)

	it("shows a Robux purchase with no items (Gleam, a pass, coffee)", function()
		CosmeticRevealStore.push({
			ids = {},
			source = "robux",
			purchase = { kind = "gleam", key = "gleam880", amount = 880 },
		})
		local shown = CosmeticRevealStore.current()
		expect(shown).to.be.ok()
		expect(shown.purchase.kind).to.equal("gleam")
		expect(shown.purchase.amount).to.equal(600)
	end)
end
