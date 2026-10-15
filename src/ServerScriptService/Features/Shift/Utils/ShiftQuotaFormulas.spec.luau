local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftQuotaFormulas = require(script.Parent.ShiftQuotaFormulas)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

return function()
	describe("quota", function()
		it("reads the crew's quota, the posted one for two", function()
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

	describe("credit", function()
		local deposit = { clearance = 15, bonus = 81, items = {} }

		it("clears everything at x1 and pays valuables only", function()
			local credit = ShiftQuotaFormulas.credit(deposit, 1)
			expect(credit.cleared).to.equal(96)
			expect(credit.earned).to.equal(81)
		end)

		it("multiplies only the pay in overtime, rounded", function()
			local credit = ShiftQuotaFormulas.credit(deposit, 1.5)
			expect(credit.cleared).to.equal(96)
			expect(credit.earned).to.equal(122)
		end)

		it("pays nothing for a trash-only load", function()
			local credit = ShiftQuotaFormulas.credit({ clearance = 30, bonus = 0, items = {} }, 1.5)
			expect(credit.cleared).to.equal(30)
			expect(credit.earned).to.equal(0)
		end)
	end)
end
