local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRevealStore = require(script.Parent.CosmeticRevealStore)
local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)

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
		-- A real Gleam pack, read from the Shop's list so a price change never breaks this spec.
		local bundle = ShopConstants.BUNDLES[1]
		CosmeticRevealStore.push({
			ids = {},
			source = "robux",
			purchase = { kind = "gleam", key = bundle.key, amount = bundle.gleam },
		})
		local shown = CosmeticRevealStore.current()
		expect(shown).to.be.ok()
		expect(shown.purchase.kind).to.equal("gleam")
		expect(shown.purchase.key).to.equal(bundle.key)
		expect(shown.purchase.amount).to.equal(bundle.gleam)
	end)
end
