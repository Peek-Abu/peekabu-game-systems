local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeLootUtils = require(script.Parent.OfficeLootUtils)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

-- 3 piles (PILE_GLOOM each), a rubbish bag on the floor and a desk recycling box (old fixtures: trash carries no Gloom and no
-- value), and three valuables: a monitor (base 100, medium: 15 Gloom), a buried plaque (a "Solid brass" jackpot, base
-- 200 = plain 80, tiny: 5) and a desk plaque (base 60, tiny: 5).
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
			{ marker = "a.desk.2", kind = "recyclingBox" },
			{ marker = "a.desk.3" },
		},
		value = 0,
	}
end

return function()
	describe("gloomOf", function()
		it("counts every pile's Gloom and every valuable's grime, by size, at full grime", function()
			local gloom = OfficeLootUtils.gloomOf(plan())
			expect(gloom.dust).to.equal(3 * VacuumConstants.PILE_GLOOM)
			expect(gloom.grime).to.equal(15 + 5 + 5)
			expect(gloom.total).to.equal(3 * VacuumConstants.PILE_GLOOM + 25)
		end)
	end)

	describe("valueOf", function()
		it("counts valuables at their plain (no-jackpot) base; trash is worth nothing", function()
			local value = OfficeLootUtils.valueOf(plan())
			expect(value.valuables).to.equal(3)
			expect(value.full).to.equal(240)
		end)

		it("prices the valuables at average cleanliness", function()
			-- 240 x (0.3 + 0.7 x 0.5) = 156.
			expect(OfficeLootUtils.valueOf(plan()).average).to.be.near(156, 1e-6)
		end)
	end)

	describe("shortfall", function()
		it("is short when the contract needs more than the max share of the site's Gloom", function()
			local total = 3 * VacuumConstants.PILE_GLOOM + 25
			local most = math.floor(total * OfficeConstants.CONTRACT_SHARE_MAX)
			expect(OfficeLootUtils.shortfall(plan(), most)).to.equal(false)
			expect(OfficeLootUtils.shortfall(plan(), most + 1)).to.equal(true)
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
