--!strict
--[=[
	Unit tests for Guard — the shared runtime argument validators. These back the `.to.throw()`
	behaviour every service relies on when a caller reaches it through an `any` cast.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guard = require(ReplicatedStorage.Shared.Core.Guard)

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

		it("throws for zero and fractions in every session", function()
			for _, isStudio in { true, false } do
				for _, bad in { 0, 1.5, -1.5 } do
					expect(function()
						Guard.userIdForSession(bad, isStudio)
					end).to.throw()
				end
			end
		end)

		-- Studio "Clients and Servers" test players are -1, -2, …; a live server never sees one.
		it("accepts a negative test id in Studio only", function()
			expect(Guard.userIdForSession(-2, true)).to.equal(-2)
			expect(function()
				Guard.userIdForSession(-2, false)
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

	describe("slotIndex", function()
		it("returns the value for a valid slot", function()
			expect(Guard.slotIndex(1, 3)).to.equal(1)
			expect(Guard.slotIndex(3, 3)).to.equal(3)
		end)

		it("rejects a non-number", function()
			expect(function()
				Guard.slotIndex("2", 3)
			end).to.throw()
		end)

		it("rejects a non-integer", function()
			expect(function()
				Guard.slotIndex(2.5, 3)
			end).to.throw()
		end)

		it("rejects a slot below 1", function()
			expect(function()
				Guard.slotIndex(0, 3)
			end).to.throw()
		end)

		it("rejects a slot above maxSlots", function()
			expect(function()
				Guard.slotIndex(4, 3)
			end).to.throw()
		end)
	end)
end
