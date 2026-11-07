local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticDevPickRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticDevPickRules)

return function()
	describe("employee", function()
		it("is off by default: no attribute picks nothing", function()
			expect(CosmeticDevPickRules.employee(true, nil)).to.equal(nil)
			expect(CosmeticDevPickRules.employee(false, nil)).to.equal(nil)
		end)

		it("picks the named employee in Studio when opted in", function()
			expect(CosmeticDevPickRules.employee(true, "Pippa")).to.equal("Pippa")
			expect(CosmeticDevPickRules.employee(true, "Cappy")).to.equal("Cappy")
		end)

		it("is never active outside Studio, whatever the attribute says", function()
			expect(CosmeticDevPickRules.employee(false, "Pippa")).to.equal(nil)
		end)

		it("ignores a value that is not a registered employee", function()
			expect(CosmeticDevPickRules.employee(true, "")).to.equal(nil)
			expect(CosmeticDevPickRules.employee(true, "NotAnEmployee")).to.equal(nil)
			expect(CosmeticDevPickRules.employee(true, true)).to.equal(nil)
			expect(CosmeticDevPickRules.employee(true, 3)).to.equal(nil)
		end)
	end)

	describe("skipsReveal", function()
		it("skips only the pick's reveal, and only when the skip is on", function()
			expect(CosmeticDevPickRules.skipsReveal(true, "Pippa", "pick")).to.equal(true)
			expect(CosmeticDevPickRules.skipsReveal(true, "Pippa", "locker")).to.equal(false)
			expect(CosmeticDevPickRules.skipsReveal(true, nil, "pick")).to.equal(false)
			expect(CosmeticDevPickRules.skipsReveal(false, "Pippa", "pick")).to.equal(false)
		end)
	end)
end
