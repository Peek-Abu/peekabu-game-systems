local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LockerConstants = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerConstants)
local LockerRules = require(script.Parent.LockerRules)

return function()
	local GLOOM = LockerConstants.LOCKERS.gloom
	local GLEAM = LockerConstants.LOCKERS.gleam

	local function item(id, rarity)
		return { id = id, kind = "skin", name = id, rarity = rarity, source = "gloomLocker", employee = "Pippa" }
	end
	-- 3 uncommon + 3 epic, like the live Gloom Locker
	local POOL = {
		item("U1", "uncommon"),
		item("U2", "uncommon"),
		item("U3", "uncommon"),
		item("E1", "epic"),
		item("E2", "epic"),
		item("E3", "epic"),
	}

	describe("pool", function()
		it("holds every catalogue item with the Locker's source", function()
			for _, it_ in LockerRules.pool(GLOOM) do
				expect(it_.source).to.equal("gloomLocker")
			end
			expect(#LockerRules.pool(GLOOM) > 0).to.equal(true)
		end)
	end)

	describe("odds", function()
		it("drops rarities with no items and scales the rest to 100%", function()
			local odds = LockerRules.odds(GLOOM, POOL)
			expect(#odds.rarities).to.equal(2)
			local total = 0
			for _, r in odds.rarities do
				total += r.chance
				expect(r.rarity == "uncommon" or r.rarity == "epic").to.equal(true)
			end
			expect(math.abs(total - 1) < 1e-9).to.equal(true)
			-- 72 vs 7 of the weights
			expect(math.abs(odds.epicPlus - 7 / 79) < 1e-9).to.equal(true)
		end)

		it("works the pity number out from the odds: ceil(1.5 / chance of Epic+)", function()
			local odds = LockerRules.odds(GLOOM, POOL)
			expect(odds.pityAt).to.equal(math.ceil(LockerConstants.PITY_FACTOR / (7 / 79)))
		end)

		it("has no pity when the pool has no Epic+", function()
			local odds = LockerRules.odds(GLOOM, { item("U1", "uncommon") })
			expect(odds.pityAt).to.equal(nil)
			expect(odds.epicPlus).to.equal(0)
		end)

		it("is empty for an empty pool", function()
			local odds = LockerRules.odds(GLEAM, {})
			expect(#odds.rarities).to.equal(0)
		end)
	end)

	describe("roll", function()
		it("picks the rarity by the first number and the item by the second", function()
			local low = LockerRules.roll(GLOOM, 0, 0.0, 0.0, POOL)
			expect(low.id).to.equal("U1")
			local high = LockerRules.roll(GLOOM, 0, 0.999, 0.999, POOL)
			expect(high.id).to.equal("E3")
		end)

		it("forces an Epic+ on the open that reaches the pity number", function()
			local pityAt = LockerRules.odds(GLOOM, POOL).pityAt
			local forced, guaranteed = LockerRules.roll(GLOOM, pityAt - 1, 0.0, 0.0, POOL)
			expect(forced.rarity).to.equal("epic")
			expect(guaranteed).to.equal(true)
			local normal, notForced = LockerRules.roll(GLOOM, pityAt - 2, 0.0, 0.0, POOL)
			expect(normal.rarity).to.equal("uncommon")
			expect(notForced).to.equal(false)
		end)

		it("returns nothing from an empty pool", function()
			expect(LockerRules.roll(GLEAM, 0, 0.5, 0.5, {})).to.equal(nil)
		end)
	end)

	describe("outcome", function()
		it("resets pity on an Epic+ and counts it up otherwise", function()
			local epic = LockerRules.outcome(GLOOM, item("E1", "epic"), false, 5, false)
			expect(epic.pity).to.equal(0)
			local common = LockerRules.outcome(GLOOM, item("U1", "uncommon"), false, 5, false)
			expect(common.pity).to.equal(6)
		end)

		it("refunds a duplicate by rarity, and nothing for a new item", function()
			local dupe = LockerRules.outcome(GLOOM, item("E1", "epic"), true, 0, false)
			expect(dupe.duplicate).to.equal(true)
			expect(dupe.refund).to.equal(math.floor(GLOOM.keyPrice * LockerConstants.REFUND.epic))
			local fresh = LockerRules.outcome(GLOOM, item("U1", "uncommon"), false, 0, false)
			expect(fresh.refund).to.equal(0)
		end)
	end)

	describe("checkOpen", function()
		it("opens with a key, or with enough money for one", function()
			expect((LockerRules.checkOpen(GLOOM, 6, 1, 0, false))).to.equal(true)
			expect((LockerRules.checkOpen(GLOOM, 6, 0, 300, false))).to.equal(true)
		end)

		it("refuses an empty Locker, a short balance, and a restricted player on a paid Locker", function()
			local _, empty = LockerRules.checkOpen(GLEAM, 0, 5, 9999, false)
			expect(empty).to.equal("empty")
			local _, short = LockerRules.checkOpen(GLOOM, 6, 0, 299, false)
			expect(short).to.equal("short")
			local _, restricted = LockerRules.checkOpen(GLEAM, 6, 5, 9999, true)
			expect(restricted).to.equal("restricted")
			-- the Gloom Locker is not a paid random item
			expect((LockerRules.checkOpen(GLOOM, 6, 1, 0, true))).to.equal(true)
		end)
	end)

	describe("checkDirect", function()
		local epic = { id = "X", kind = "skin", name = "X", rarity = "epic", source = "gleamLocker" }
		it("sells a paid Locker's item to a restricted player at the raised price", function()
			expect(LockerRules.directPrice(epic)).to.equal(LockerConstants.DIRECT_PRICE.epic)
			expect((LockerRules.checkDirect(GLEAM, epic, false, 750, true))).to.equal(true)
		end)

		it("refuses players who can open it, other Lockers' items, owned items and short balances", function()
			local _, open = LockerRules.checkDirect(GLEAM, epic, false, 9999, false)
			expect(open).to.equal("not restricted")
			local other = table.clone(epic)
			other.source = "gloomLocker"
			local _, wrong = LockerRules.checkDirect(GLEAM, other, false, 9999, true)
			expect(wrong).to.equal("not in this locker")
			local _, owned = LockerRules.checkDirect(GLEAM, epic, true, 9999, true)
			expect(owned).to.equal("owned")
			local _, short = LockerRules.checkDirect(GLEAM, epic, false, 749, true)
			expect(short).to.equal("short")
		end)
	end)

	describe("validate", function()
		it("accepts the default and rejects negative or unknown counts", function()
			expect(LockerRules.validate({ keys = {}, pity = {}, opened = 0 })).to.equal(true)
			expect(LockerRules.validate({ keys = { gloom = 2 }, pity = { gleam = 3 }, opened = 5 })).to.equal(true)
			expect(LockerRules.validate({ keys = { gloom = -1 }, pity = {}, opened = 0 })).to.equal(false)
			expect(LockerRules.validate({ keys = { nope = 1 }, pity = {}, opened = 0 })).to.equal(false)
			expect(LockerRules.validate({ keys = {}, pity = {}, opened = 1.5 })).to.equal(false)
		end)
	end)
end
