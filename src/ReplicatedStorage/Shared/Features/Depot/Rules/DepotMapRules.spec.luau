local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotMapRules = require(script.Parent.DepotMapRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

return function()
	describe("parse", function()
		it("keeps the two map ids", function()
			expect(DepotMapRules.parse("office")).to.equal("office")
			expect(DepotMapRules.parse("school")).to.equal("school")
		end)

		it("reads anything else as the office", function()
			expect(DepotMapRules.parse(nil)).to.equal("office")
			expect(DepotMapRules.parse("School")).to.equal("office")
			expect(DepotMapRules.parse("hospital")).to.equal("office")
			expect(DepotMapRules.parse(1)).to.equal("office")
			expect(DepotMapRules.parse(true)).to.equal("office")
			expect(DepotMapRules.parse({ "school" })).to.equal("office")
		end)
	end)

	describe("isMap", function()
		it("accepts only the two map ids", function()
			expect(DepotMapRules.isMap("office")).to.equal(true)
			expect(DepotMapRules.isMap("school")).to.equal(true)
			expect(DepotMapRules.isMap("")).to.equal(false)
			expect(DepotMapRules.isMap("gym")).to.equal(false)
			expect(DepotMapRules.isMap(nil)).to.equal(false)
			expect(DepotMapRules.isMap(2)).to.equal(false)
		end)
	end)

	describe("canPick", function()
		it("lets only the truck's host pick", function()
			expect(DepotMapRules.canPick(7, 7)).to.equal(true)
			expect(DepotMapRules.canPick(8, 7)).to.equal(false)
		end)

		it("lets nobody pick on a truck with no host", function()
			expect(DepotMapRules.canPick(7, nil)).to.equal(false)
		end)
	end)

	describe("decode", function()
		it("reads each truck's pick", function()
			local picks = DepotMapRules.decode({ pad1 = "school", pad2 = "office" })
			expect(picks.pad1).to.equal("school")
			expect(picks.pad2).to.equal("office")
		end)

		it("drops bad entries and keeps the good ones", function()
			local picks = DepotMapRules.decode({ pad1 = "gym", pad2 = 3, pad3 = "school", [4] = "school" })
			expect(picks.pad1).to.equal(nil)
			expect(picks.pad2).to.equal(nil)
			expect(picks.pad3).to.equal("school")
			expect(picks[4]).to.equal(nil)
		end)

		it("is empty for a missing or malformed entry", function()
			expect(next(DepotMapRules.decode(nil))).to.equal(nil)
			expect(next(DepotMapRules.decode("school"))).to.equal(nil)
		end)
	end)

	describe("mapOf", function()
		it("is the truck's pick, else the office", function()
			local picks = DepotMapRules.decode({ pad1 = "school" })
			expect(DepotMapRules.mapOf(picks, "pad1")).to.equal("school")
			expect(DepotMapRules.mapOf(picks, "pad2")).to.equal("office")
			expect(DepotMapRules.mapOf(picks, nil)).to.equal("office")
		end)
	end)

	describe("contractsOf", function()
		it("is the office's jobs on the office, unchanged", function()
			expect(DepotMapRules.contractsOf("office")).to.equal(DepotConstants.CONTRACTS)
			expect(DepotMapRules.contractsOf("office")[1].client).to.equal("Harlow & Finch Ltd.")
		end)

		it("is the school's own jobs on the school, none of them Harlow & Finch", function()
			local list = DepotMapRules.contractsOf("school")
			expect(#list > 0).to.equal(true)
			for _, contract in list do
				expect(contract.client).to.equal("Maple Hill School")
				expect(string.find(contract.job, "office", 1, true)).to.equal(nil)
				expect(string.find(contract.note, "manager", 1, true)).to.equal(nil)
			end
			expect(list[1].job).to.equal("Clean the school before Monday.")
		end)

		it("never shares a contract id between maps", function()
			local seen = {}
			for _, map in { "office", "school" } do
				for _, contract in DepotMapRules.contractsOf(map) do
					expect(seen[contract.id]).to.equal(nil)
					seen[contract.id] = true
				end
			end
		end)
	end)

	describe("siteOf", function()
		it("keeps the office's words as they were", function()
			local site = DepotMapRules.siteOf("office")
			expect(site.site).to.equal(DepotConstants.SITE)
			expect(site.hud).to.equal("Harlow & Finch · offices")
			expect(site.tip).to.equal(DepotConstants.BOARD_COPY.hazard)
			expect(site.reviewTab).to.equal("SHIFT REVIEW · HARLOW & FINCH")
			expect(site.quote).to.equal(ShiftConstants.REVIEW_QUOTES.met)
		end)

		it("gives the school its own words, with a tip about Bramble and no Office or Manager", function()
			local site = DepotMapRules.siteOf("school")
			expect(site.tip).to.equal("Bramble the owl can't move while you look at it. Watch it and take turns!")
			for _, text in { site.site, site.hud, site.tip, site.reviewTab, site.quote.line, site.quote.by } do
				expect(string.find(string.lower(text), "office", 1, true)).to.equal(nil)
				expect(string.find(string.lower(text), "manager", 1, true)).to.equal(nil)
				expect(string.find(string.lower(text), "harlow", 1, true)).to.equal(nil)
			end
		end)
	end)
end
