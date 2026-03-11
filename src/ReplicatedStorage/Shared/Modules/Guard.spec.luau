--!strict
--[=[
	Unit tests for Guard — the shared runtime argument validators. These back the `.to.throw()`
	behaviour every service relies on when a caller reaches it through an `any` cast.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guard = require(ReplicatedStorage.Shared.Modules.Guard)

return function()
	describe("userId", function()
		it("returns the value for a number", function()
			expect(Guard.userId(123)).to.equal(123)
		end)

		it("throws for a non-number", function()
			expect(function()
				Guard.userId("bad")
			end).to.throw()
			expect(function()
				Guard.userId(nil)
			end).to.throw()
		end)
	end)

	describe("positiveAmount", function()
		it("returns the value for a positive number", function()
			expect(Guard.positiveAmount(5)).to.equal(5)
		end)

		it("throws for zero, negatives, and non-numbers", function()
			expect(function()
				Guard.positiveAmount(0)
			end).to.throw()
			expect(function()
				Guard.positiveAmount(-1)
			end).to.throw()
			expect(function()
				Guard.positiveAmount("bad")
			end).to.throw()
		end)
	end)

	describe("nonNegativeAmount", function()
		it("allows zero and positives", function()
			expect(Guard.nonNegativeAmount(0)).to.equal(0)
			expect(Guard.nonNegativeAmount(10)).to.equal(10)
		end)

		it("throws for negatives and non-numbers", function()
			expect(function()
				Guard.nonNegativeAmount(-1)
			end).to.throw()
			expect(function()
				Guard.nonNegativeAmount("bad")
			end).to.throw()
		end)
	end)
end
