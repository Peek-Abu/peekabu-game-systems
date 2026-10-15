local ServerScriptService = game:GetService("ServerScriptService")

local OfficeLootUtils = require(script.Parent.OfficeLootUtils)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)

-- 3 piles (one dust bag, 15), a rubbish bag on the floor (10), a desk bottle bag (15), and three valuables: a monitor
-- (base 100), a buried plaque (a "Solid brass" jackpot, base 200 = plain 80) and a desk plaque (base 60).
local function plan()
	return {
		piles = {
			{
				marker = "a.pile.1",
				kind = "paper",
				hides = "plaque",
				appraisal = { base = 200, variant = "Solid brass" },
			},
			{ marker = "a.pile.2", kind = "paper" },
			{ marker = "a.pile.3", kind = "paper" },
		},
		items = {
			{ marker = "a.item.1", kind = "monitor", appraisal = { base = 100 } },
			{ marker = "a.item.2", kind = "rubbishBag" },
		},
		searchables = {
			{ marker = "a.desk.1", kind = "plaque", appraisal = { base = 60 } },
			{ marker = "a.desk.2", kind = "bottleBag" },
			{ marker = "a.desk.3" },
		},
		value = 0,
	}
end

return function()
	describe("pileTrash", function()
		it("makes one dust bag per full canister of piles", function()
			expect(OfficeLootUtils.pileTrash(2)).to.equal(0)
			expect(OfficeLootUtils.pileTrash(3)).to.equal(15)
			expect(OfficeLootUtils.pileTrash(7)).to.equal(30)
		end)
	end)

	describe("valueOf", function()
		it("counts valuables at their plain (no-jackpot) base, trash and the piles' dust bags", function()
			local value = OfficeLootUtils.valueOf(plan())
			expect(value.valuables).to.equal(3)
			expect(value.trash).to.equal(40)
			expect(value.full).to.equal(240 + 40)
		end)

		it("prices the valuables at average cleanliness for the guarantee", function()
			local value = OfficeLootUtils.valueOf(plan())
			-- 240 x (0.3 + 0.7 x 0.5) = 156, plus 40 trash.
			expect(value.average).to.be.near(196, 1e-6)
		end)
	end)

	describe("shortfall", function()
		it("is short when the quota needs more than the max share of the average value", function()
			-- 196 x 0.75 = 147.
			expect(OfficeLootUtils.shortfall(plan(), 146)).to.equal(false)
			expect(OfficeLootUtils.shortfall(plan(), 148)).to.equal(true)
		end)
	end)

	describe("buried", function()
		it("draws once per pile and buries where the draw hits, capped by the budget", function()
			local draws = { 0.1, 0.9, 0.2, 0.3 }
			local index = 0
			local rng = {
				NextNumber = function()
					index += 1
					return draws[index]
				end,
			}
			local hits = OfficeLootUtils.buried(4, 2, rng)
			expect(index).to.equal(4)
			expect(#hits).to.equal(2)
			expect(hits[1]).to.equal(1)
			expect(hits[2]).to.equal(3)
		end)

		it("buries about BURY_CHANCE of the piles over many seeds", function()
			local rng = Random.new(11)
			local total = 0
			for _ = 1, 200 do
				total += #OfficeLootUtils.buried(10, 10, rng)
			end
			local share = total / 2000
			expect(math.abs(share - OfficeConstants.BURY_CHANCE) < 0.05).to.equal(true)
		end)

		it("buries nothing with no room in the budget", function()
			expect(#OfficeLootUtils.buried(6, 0, Random.new(1))).to.equal(0)
		end)
	end)
end
