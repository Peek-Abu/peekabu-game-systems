local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DealRules = require(ReplicatedStorage.Shared.Features.Deal.Rules.DealRules)

local function ownsOf(list)
	local set = {}
	for _, id in list do
		set[id] = true
	end
	return function(id)
		return set[id] == true
	end
end

return function()
	describe("fresh and validate", function()
		it("starts with nothing bought and no picks", function()
			local slice = DealRules.fresh()
			expect(next(slice.bought)).to.equal(nil)
			expect(next(slice.picks)).to.equal(nil)
			expect((DealRules.validate(slice))).to.equal(true)
		end)

		it("accepts known deals with whole pick counts and refuses anything else", function()
			expect((DealRules.validate({ bought = { pickLegendary = true }, picks = { pickLegendary = 1 } }))).to.equal(
				true
			)
			expect((DealRules.validate({ bought = { other = true }, picks = {} }))).to.equal(false)
			expect((DealRules.validate({ bought = {}, picks = { pickNewHire = -1 } }))).to.equal(false)
			expect((DealRules.validate({ bought = {}, picks = { pickNewHire = 0.5 } }))).to.equal(false)
			expect((DealRules.validate({ bought = { pickNewHire = false }, picks = {} }))).to.equal(false)
		end)
	end)

	describe("choices", function()
		it("Pick a Legendary offers only Legendary skins of hired employees the player does not own yet", function()
			local choices = DealRules.choices("pickLegendary", ownsOf({ "Pippa" }))
			expect(#choices).to.equal(1)
			expect(choices[1]).to.equal("Pippa.BubbleBuddy")
			local both = DealRules.choices("pickLegendary", ownsOf({ "Pippa", "Cappy", "Pippa.BubbleBuddy" }))
			expect(#both).to.equal(1)
			expect(both[1]).to.equal("Cappy.PJ")
		end)

		it("Pick a New Hire offers the employees not hired yet that can be hired", function()
			local choices = DealRules.choices("pickNewHire", ownsOf({ "Pippa" }))
			expect(#choices).to.equal(2)
			expect(table.find(choices, "Cappy")).to.be.ok()
			expect(table.find(choices, "Prickles")).to.be.ok()
			expect(table.find(choices, "Pippa")).to.equal(nil)
			expect(#DealRules.choices("pickNewHire", ownsOf({ "Pippa", "Cappy", "Prickles" }))).to.equal(0)
		end)
	end)

	describe("offered", function()
		it("shows a deal until it is bought, and never when nothing is left to pick", function()
			local owns = ownsOf({ "Pippa" })
			expect(DealRules.offered("pickLegendary", DealRules.fresh(), owns)).to.equal(true)
			local bought = { bought = { pickLegendary = true }, picks = {} }
			expect(DealRules.offered("pickLegendary", bought, owns)).to.equal(false)
			expect(DealRules.offered("pickLegendary", DealRules.fresh(), ownsOf({ "Pippa", "Pippa.BubbleBuddy" }))).to.equal(
				false
			)
			expect(DealRules.offered("pickNewHire", DealRules.fresh(), ownsOf({ "Pippa", "Cappy", "Prickles" }))).to.equal(
				false
			)
		end)

		it("lists the offered deals in the shop's order", function()
			local list = DealRules.offeredList(DealRules.fresh(), ownsOf({ "Pippa" }))
			expect(#list).to.equal(2)
			expect(list[1]).to.equal("pickLegendary")
			expect(list[2]).to.equal("pickNewHire")
		end)
	end)

	describe("purchase and choose", function()
		it("a receipt marks the deal bought and adds one unspent pick (twice = two picks)", function()
			local slice = DealRules.fresh()
			DealRules.applyPurchase(slice, "pickLegendary")
			expect(slice.bought.pickLegendary).to.equal(true)
			expect(slice.picks.pickLegendary).to.equal(1)
			DealRules.applyPurchase(slice, "pickLegendary")
			expect(slice.picks.pickLegendary).to.equal(2)
		end)

		it("pending is the first deal with a pick and something to pick", function()
			local owns = ownsOf({ "Pippa" })
			local slice = DealRules.fresh()
			expect(DealRules.pending(slice, owns)).to.equal(nil)
			DealRules.applyPurchase(slice, "pickNewHire")
			expect(DealRules.pending(slice, owns)).to.equal("pickNewHire")
			expect(DealRules.pending(slice, ownsOf({ "Pippa", "Cappy", "Prickles" }))).to.equal(nil)
		end)

		it("a choice needs an unspent pick and one of the offered choices", function()
			local owns = ownsOf({ "Pippa" })
			local slice = DealRules.fresh()
			expect((DealRules.canChoose("pickLegendary", "Pippa.BubbleBuddy", slice, owns))).to.equal(false)
			DealRules.applyPurchase(slice, "pickLegendary")
			expect((DealRules.canChoose("pickLegendary", "Pippa.BubbleBuddy", slice, owns))).to.equal(true)
			expect((DealRules.canChoose("pickLegendary", "Cappy.PJ", slice, owns))).to.equal(false)
			expect((DealRules.canChoose("pickLegendary", "Pippa.Classic", slice, owns))).to.equal(false)
		end)

		it("spending a pick takes one away and never goes below zero", function()
			local slice = DealRules.fresh()
			DealRules.applyPurchase(slice, "pickNewHire")
			expect(DealRules.spend(slice, "pickNewHire")).to.equal(true)
			expect(slice.picks.pickNewHire).to.equal(nil)
			expect(DealRules.spend(slice, "pickNewHire")).to.equal(false)
		end)

		it(
			"grants the Legendary skin's whole bundle for a Legendary pick, and the employee plus it for a New Hire",
			function()
				local CosmeticBundleRegistry =
					require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticBundleRegistry)
				local pj = CosmeticBundleRegistry.containing("Cappy.PJ")[1]
				local legendary = DealRules.grants("pickLegendary", "Cappy.PJ")
				expect(#legendary).to.equal(#pj.items)
				for _, id in pj.items do
					expect(table.find(legendary, id)).to.be.ok()
				end
				-- "Pick any Legendary skin + its emote, stickers and idle": its whole bundle comes with it.
				expect(table.find(legendary, "Cappy.CocoaSip")).to.be.ok()
				expect(table.find(legendary, "CozyPack")).to.be.ok()
				local hire = DealRules.grants("pickNewHire", "Prickles")
				expect(hire[1]).to.equal("Prickles")
				expect(table.find(hire, "Prickles.Sheriff")).to.be.ok()
				expect(table.find(hire, "Prickles.Lasso")).to.be.ok()
				expect(#hire).to.equal(1 + #CosmeticBundleRegistry.containing("Prickles.Sheriff")[1].items)
			end
		)

		it("knows each employee's Legendary skin", function()
			expect(DealRules.legendaryOf("Cappy")).to.equal("Cappy.PJ")
			expect(DealRules.legendaryOf("Pippa")).to.equal("Pippa.BubbleBuddy")
			expect(DealRules.legendaryOf("Nobody")).to.equal(nil)
		end)
	end)

	describe("parse", function()
		it("accepts a known deal id and a short choice only", function()
			expect(DealRules.parseDeal("pickLegendary")).to.equal("pickLegendary")
			expect(DealRules.parseDeal("free")).to.equal(nil)
		end)
	end)
end
