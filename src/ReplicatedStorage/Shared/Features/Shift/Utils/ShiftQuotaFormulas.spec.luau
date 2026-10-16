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
			expect(ShiftQuotaFormulas.pay(deposit, 1)).to.equal(81)
		end)

		it("multiplies the valuables in overtime, rounded", function()
			expect(ShiftQuotaFormulas.pay(deposit, 1.5)).to.equal(122)
		end)

		it("pays nothing for a trash-only load", function()
			expect(ShiftQuotaFormulas.pay({ clearance = 30, bonus = 0, items = {} }, 1.5)).to.equal(0)
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
			expect(split.dustGleam).to.equal(260 * ShiftConstants.GLEAM_PER_GLOOM)
			expect(split.grimeGleam).to.equal(80 * ShiftConstants.GLEAM_PER_GLOOM)
			expect(split.valuables).to.equal(420)
			expect(split.gleam).to.equal(340 * ShiftConstants.GLEAM_PER_GLOOM + 420)
		end)

		it("never reads more dust than Gloom, nor anything negative", function()
			local split = ShiftQuotaFormulas.breakdown(40, 60, -5)
			expect(split.dust).to.equal(40)
			expect(split.grime).to.equal(0)
			expect(split.valuables).to.equal(0)
			expect(split.gleam).to.equal(40 * ShiftConstants.GLEAM_PER_GLOOM)
		end)
	end)
end
