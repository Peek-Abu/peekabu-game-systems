local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local ShopRules = require(script.Parent.ShopRules)

return function()
	local NOON = 1792929600

	local function owner(ids)
		local set = {}
		for _, id in ids or {} do
			set[id] = true
		end
		return function(id)
			return set[id] == true
		end
	end

	it("allows a buy you can afford of something you don't own", function()
		local ok, reason = ShopRules.check(ShopRegistry.get("Pippa.BubbleBuddy"), owner(), 1500, NOON)
		expect(ok).to.equal(true)
		expect(reason).to.equal(nil)
	end)

	it("refuses what you already own, what you can't afford and what is not on sale", function()
		local bubble = ShopRegistry.get("Pippa.BubbleBuddy")
		local _, owned = ShopRules.check(bubble, owner({ "Pippa.BubbleBuddy" }), 9999, NOON)
		expect(owned).to.equal("owned")
		local _, short = ShopRules.check(bubble, owner(), 1499, NOON)
		expect(short).to.equal("short")
		local event = {
			id = "E",
			items = { "Pippa.BubbleBuddy" },
			currency = "gleam",
			price = 1,
			pool = "picks",
			ends = NOON - 1,
		}
		local _, dead = ShopRules.check(event, owner(), 9999, NOON)
		expect(dead).to.equal("not on sale")
	end)

	it("still sells a bundle when only a bundled extra is owned", function()
		local ok = ShopRules.check(ShopRegistry.get("Pippa.BubbleBuddy"), owner({ "Pippa.Bubbles" }), 1500, NOON)
		expect(ok).to.equal(true)
	end)

	it("says how much more you need", function()
		expect(ShopRules.missing(ShopRegistry.get("Prickles"), 2000)).to.equal(500)
		expect(ShopRules.missing(ShopRegistry.get("Prickles"), 9000)).to.equal(0)
	end)
end
