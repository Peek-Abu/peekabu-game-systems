local ShopRequestRules = require(script.Parent.ShopRequestRules)

return function()
	it("round-trips an offer id, with no Gleam agreed", function()
		local request = ShopRequestRules.parseBuy(ShopRequestRules.buildBuy("Pippa.BubbleBuddy"))
		expect(request.offer).to.equal("Pippa.BubbleBuddy")
		expect(request.gleam).to.equal(0)
	end)

	it("round-trips the Gleam the player agreed to pay for the rest", function()
		local request = ShopRequestRules.parseBuy(ShopRequestRules.buildBuy("Cappy", 30))
		expect(request.offer).to.equal("Cappy")
		expect(request.gleam).to.equal(30)
	end)

	it("round-trips the price the player saw, and leaves it out when none was shown", function()
		expect(ShopRequestRules.parseBuy(ShopRequestRules.buildBuy("Cappy", 0, 960)).price).to.equal(960)
		expect(ShopRequestRules.parseBuy(ShopRequestRules.buildBuy("Cappy")).price).to.equal(nil)
	end)

	it("drops anything else", function()
		for _, payload in
			{
				nil,
				"Pippa",
				{},
				{ offer = "" },
				{ offer = 3 },
				{ offer = string.rep("x", 65) },
				{ offer = "Cappy", gleam = -1 },
				{ offer = "Cappy", gleam = 1.5 },
				{ offer = "Cappy", gleam = "30" },
				{ offer = "Cappy", gleam = 0 / 0 },
				{ offer = "Cappy", gleam = math.huge },
				{ offer = "Cappy", price = -5 },
				{ offer = "Cappy", price = "960" },
				{ offer = "Cappy", price = 9.5 },
			}
		do
			local parsed, reason = ShopRequestRules.parseBuy(payload)
			expect(parsed).never.to.be.ok()
			expect(reason).to.be.a("string")
		end
	end)
end
