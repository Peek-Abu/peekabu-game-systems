local ShopRequestRules = require(script.Parent.ShopRequestRules)

return function()
	it("round-trips an offer id", function()
		expect(ShopRequestRules.parseBuy(ShopRequestRules.buildBuy("Pippa.BubbleBuddy"))).to.equal("Pippa.BubbleBuddy")
	end)

	it("drops anything else", function()
		for _, payload in { nil, "Pippa", {}, { offer = "" }, { offer = 3 }, { offer = string.rep("x", 65) } } do
			local parsed, reason = ShopRequestRules.parseBuy(payload)
			expect(parsed).never.to.be.ok()
			expect(reason).to.be.a("string")
		end
	end)
end
