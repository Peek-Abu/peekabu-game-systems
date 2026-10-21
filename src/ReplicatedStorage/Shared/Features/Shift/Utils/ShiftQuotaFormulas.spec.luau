local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftQuotaFormulas = require(script.Parent.ShiftQuotaFormulas)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

return function()
	describe("quota", function()
		it("reads the crew's contract, the posted one for two", function()
			expect(ShiftQuotaFormulas.quota(1)).to.equal(ShiftConstants.QUOTA_BY_CREW[1])
			expect(ShiftQuotaFormulas.quota(2)).to.equal(ShiftConstants.QUOTA)
			expect(ShiftQuotaFormulas.quota(4)).to.equal(ShiftConstants.QUOTA_BY_CREW[4])
		end)

		it("never shrinks with a bigger crew", function()
			for crew = 2, #ShiftConstants.QUOTA_BY_CREW do
				expect(ShiftQuotaFormulas.quota(crew) >= ShiftQuotaFormulas.quota(crew - 1)).to.equal(true)
			end
		end)

		it("clamps an empty or oversized crew to the table", function()
			expect(ShiftQuotaFormulas.quota(0)).to.equal(ShiftConstants.QUOTA_BY_CREW[1])
			expect(ShiftQuotaFormulas.quota(9)).to.equal(ShiftConstants.QUOTA_BY_CREW[#ShiftConstants.QUOTA_BY_CREW])
		end)
	end)

	describe("pay", function()
		local deposit = { clearance = 15, bonus = 81, items = {} }

		it("pays the valuables banked, and banking adds no Gloom", function()
			expect(ShiftQuotaFormulas.pay(deposit)).to.equal(81)
		end)

		it("pays one overtime item x1.5 and the normal one x1", function()
			local mixed = {
				clearance = 0,
				bonus = 20,
				items = {
					{ kind = "plaque", category = "salvage", value = 10, overtime = true },
					{ kind = "plaque", category = "salvage", value = 10, overtime = false },
				},
			}
			expect(ShiftQuotaFormulas.pay(mixed)).to.equal(25)
		end)

		it("pays a normal item x1 even for a Load banked in overtime", function()
			local normal = {
				clearance = 0,
				bonus = 10,
				items = { { kind = "plaque", category = "salvage", value = 10, overtime = false } },
			}
			expect(ShiftQuotaFormulas.pay(normal)).to.equal(10)
		end)

		it("rounds once on the total", function()
			local odd = {
				clearance = 0,
				bonus = 9,
				items = {
					{ kind = "plaque", category = "salvage", value = 3, overtime = true },
					{ kind = "plaque", category = "salvage", value = 3, overtime = true },
					{ kind = "plaque", category = "salvage", value = 3, overtime = false },
				},
			}
			expect(ShiftQuotaFormulas.pay(odd)).to.equal(14)
		end)

		it("pays nothing for a trash-only load, overtime flag or not", function()
			local trash = {
				clearance = 30,
				bonus = 0,
				items = { { kind = "rubbishBag", category = "trash", value = 30, overtime = true } },
			}
			expect(ShiftQuotaFormulas.pay(trash)).to.equal(0)
		end)
	end)

	describe("pileGloom", function()
		it("is the vacuum's per-pile Gloom", function()
			expect(ShiftQuotaFormulas.pileGloom()).to.equal(VacuumConstants.PILE_GLOOM)
		end)
	end)

	describe("breakdown", function()
		it("splits the Gloom removed into dust and item cleaning, and pays each, plus the valuables", function()
			local split = ShiftQuotaFormulas.breakdown(340, 260, 420)
			expect(split.dust).to.equal(260)
			expect(split.grime).to.equal(80)
			expect(split.gloom).to.equal(340)
			expect(split.dustCredits).to.equal(260 * ShiftConstants.CREDITS_PER_GLOOM)
			expect(split.grimeCredits).to.equal(80 * ShiftConstants.CREDITS_PER_GLOOM)
			expect(split.valuables).to.equal(420)
			expect(split.credits).to.equal(340 * ShiftConstants.CREDITS_PER_GLOOM + 420)
		end)

		it("never reads more dust than Gloom, nor anything negative", function()
			local split = ShiftQuotaFormulas.breakdown(40, 60, -5)
			expect(split.dust).to.equal(40)
			expect(split.grime).to.equal(0)
			expect(split.valuables).to.equal(0)
			expect(split.credits).to.equal(40 * ShiftConstants.CREDITS_PER_GLOOM)
		end)
	end)

	describe("savedGloom", function()
		it("keeps a tenth of the Gloom removed, floored, never below zero", function()
			expect(ShiftQuotaFormulas.savedGloom(362)).to.equal(36)
			expect(ShiftQuotaFormulas.savedGloom(9)).to.equal(0)
			expect(ShiftQuotaFormulas.savedGloom(-5)).to.equal(0)
		end)
	end)
end
