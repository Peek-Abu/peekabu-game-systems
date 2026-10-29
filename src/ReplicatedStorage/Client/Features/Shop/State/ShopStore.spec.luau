local ShopStore = require(script.Parent.ShopStore)

return function()
	afterEach(function()
		ShopStore.reset()
	end)

	it("opens a product page and closes it", function()
		ShopStore.open("Pippa.BubbleBuddy")
		expect(ShopStore.product()).to.equal("Pippa.BubbleBuddy")
		ShopStore.close()
		expect(ShopStore.product()).to.equal(nil)
	end)

	it("keeps each pass's fetched price and icon, and forgets them on reset", function()
		ShopStore.setPassInfo("bigCrew", { price = 149, icon = "rbxassetid://5", name = "Big Crew", forSale = true })
		expect(ShopStore.passInfo().bigCrew.price).to.equal(149)
		ShopStore.reset()
		expect(ShopStore.passInfo().bigCrew).to.equal(nil)
	end)

	it("keeps the last buy result, clearing it when another page opens", function()
		ShopStore.setResult({ offer = "Prickles", reason = "short" })
		expect(ShopStore.result().reason).to.equal("short")
		ShopStore.open("Cappy")
		expect(ShopStore.result()).to.equal(nil)
	end)
end
