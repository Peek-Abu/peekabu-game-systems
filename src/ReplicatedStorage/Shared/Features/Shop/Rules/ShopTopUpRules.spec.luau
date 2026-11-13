local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopTopUpRules = require(script.Parent.ShopTopUpRules)

return function()
	local rate = ShopConstants.TOP_UP.credits

	it("tops up Credits at the set rate, rounding the Gleam up", function()
		expect(rate).to.be.a("number")
		expect(ShopTopUpRules.gleamFor("credits", rate * 30)).to.equal(30)
		expect(ShopTopUpRules.gleamFor("credits", rate * 30 - 1)).to.equal(30)
		expect(ShopTopUpRules.gleamFor("credits", 1)).to.equal(1)
		expect(ShopTopUpRules.gleamFor("credits", 0)).to.equal(0)
	end)

	it("never tops up Gleam itself, or a currency without a rate", function()
		expect(ShopTopUpRules.gleamFor("gleam", 100)).to.equal(nil)
		expect(ShopTopUpRules.gleamFor("robux", 100)).to.equal(nil)
		if ShopConstants.TOP_UP.gloom == nil then
			expect(ShopTopUpRules.gleamFor("gloom", 100)).to.equal(nil)
		end
	end)

	it("plans the rest: all the Gleam needed, and only the Credits the Gleam does not cover", function()
		-- 2,500 price, 2,205 Credits: 295 short.
		local plan = ShopTopUpRules.plan("credits", 2500, 2205)
		local gleam = math.ceil(295 / rate)
		expect(plan.gleam).to.equal(gleam)
		expect(plan.spend).to.equal(2500 - gleam * rate)
		expect(plan.spend <= 2205).to.equal(true)
		-- The player never loses the rounding: what they keep is what the Gleam over-covered.
		expect(2205 - plan.spend).to.equal(gleam * rate - 295)
	end)

	it("plans a hire from zero Credits as all Gleam", function()
		local plan = ShopTopUpRules.plan("credits", 2500, 0)
		expect(plan.gleam).to.equal(math.ceil(2500 / rate))
		expect(plan.spend).to.equal(0)
	end)

	it("has no plan when the player can already pay, or the currency cannot be topped up", function()
		expect(ShopTopUpRules.plan("credits", 2500, 2500)).to.equal(nil)
		expect(ShopTopUpRules.plan("credits", 2500, 9000)).to.equal(nil)
		expect(ShopTopUpRules.plan("gleam", 1500, 100)).to.equal(nil)
	end)

	it("treats a negative balance as zero", function()
		local plan = ShopTopUpRules.plan("credits", 100, -50)
		expect(plan.gleam).to.equal(math.ceil(100 / rate))
		expect(plan.spend).to.equal(0)
	end)
end
