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
		local ok, reason = ShopRules.check(ShopRegistry.get("Pippa.BubbleBuddy"), owner(), 1600, NOON)
		expect(ok).to.equal(true)
		expect(reason).to.equal(nil)
	end)

	it("refuses what you already own, what you can't afford and what is not on sale", function()
		local bubble = ShopRegistry.get("Pippa.BubbleBuddy")
		local _, owned = ShopRules.check(bubble, owner({ "Pippa.BubbleBuddy" }), 9999, NOON)
		expect(owned).to.equal("owned")
		local _, short = ShopRules.check(bubble, owner(), 1599, NOON)
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

	it("sells an event's offer only while its event is live", function()
		local harvest = ShopRegistry.get("HarvestPack")
		expect(harvest).to.be.ok()
		local ok = ShopRules.check(harvest, owner(), harvest.price, NOON, "harvest")
		expect(ok).to.equal(true)
		local _, closed = ShopRules.check(harvest, owner(), harvest.price, NOON)
		expect(closed).to.equal("not on sale")
	end)

	it("still sells a bundle when only a bundled extra is owned", function()
		local ok = ShopRules.check(ShopRegistry.get("Pippa.BubbleBuddy"), owner({ "Pippa.Bubbles" }), 1600, NOON)
		expect(ok).to.equal(true)
	end)

	it("says how much more you need", function()
		expect(ShopRules.missing(ShopRegistry.get("Prickles"), 2000)).to.equal(3000)
		expect(ShopRules.missing(ShopRegistry.get("Prickles"), 9000)).to.equal(0)
	end)

	-- A buy's top rarity (owner, legendary purchase sting 2026-11-17: "if bundle - highest rarity item").
	describe("topRarity", function()
		local function offer(items)
			return { id = "Test", items = items, currency = "gleam", price = 1, pool = "picks" }
		end

		it("is a single item's own rarity", function()
			expect(ShopRules.topRarity(ShopRegistry.get("Pippa.BubbleBuddy"))).to.equal("legendary")
			expect(ShopRules.topRarity(ShopRegistry.get("Prickles"))).to.equal("default")
		end)

		it("is a bundle's highest-rarity item, wherever it sits in the bundle", function()
			expect(ShopRules.topRarity(offer({ "Pippa.Bubbles", "Cappy.PJ", "Pippa.GloomTouched" }))).to.equal(
				"legendary"
			)
			expect(ShopRules.topRarity(offer({ "Pippa.GloomTouched", "Pippa.Bubbles" }))).to.equal("epic")
			expect(ShopRules.topRarity(ShopRegistry.get("Bundle.BubbleBuddy"))).to.equal("legendary")
		end)

		it("skips unknown items, and is nil when it knows none", function()
			expect(ShopRules.topRarity(offer({ "Nope", "Pippa.GloomTouched" }))).to.equal("uncommon")
			expect(ShopRules.topRarity(offer({ "Nope" }))).to.equal(nil)
			expect(ShopRules.topRarity(offer({}))).to.equal(nil)
		end)
	end)
end
