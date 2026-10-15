local Banking = require(script.Parent.ShiftBankingSystem)
return function()
	describe("banker eligibility boundary", function()
		it("refuses a non-crew banker before reading multiplier or touching any counters", function()
			local player = { UserId = 9017, Name = "CargoSpecPlayer", DisplayName = "Cargo Spec" }
			local checked
			local handler = Banking.new({
				isOpen = function()
					return true
				end,
				canBank = function(candidate)
					checked = candidate
					return false
				end,
				multiplier = function()
					error("an ineligible banker must not reach counter computation")
				end,
				afterBank = function()
					error("an ineligible banker must not advance shift state")
				end,
			})
			local accepted = handler(player, { clearance = 20, bonus = 25, items = {} })
			expect(accepted).to.equal(false)
			expect(checked).to.equal(player)
		end)
		it("refuses a closed shift before evaluating crew eligibility", function()
			local player = { UserId = 9017, Name = "CargoSpecPlayer", DisplayName = "Cargo Spec" }
			local handler = Banking.new({
				isOpen = function()
					return false
				end,
				canBank = function()
					error("closed shifts never bank")
				end,
			})
			expect(handler(player, { clearance = 20, bonus = 0, items = {} })).to.equal(false)
		end)
	end)
end
