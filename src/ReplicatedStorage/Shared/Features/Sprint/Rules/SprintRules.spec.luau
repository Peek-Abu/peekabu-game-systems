local SprintRules = require(script.Parent.SprintRules)

local function input(extra)
	local value = { requested = true, alive = true, frozen = false, hidden = false, crouching = false, stamina = true }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("canSprint", function()
		local function refused(extra, expected)
			local ok, reason = SprintRules.canSprint(input(extra))
			expect(ok).to.equal(false)
			expect(reason).to.equal(expected)
		end

		it("sprints a living, free player who asks and has the stamina", function()
			expect(SprintRules.canSprint(input())).to.equal(true)
		end)

		it("refuses without asking, dead, frozen, hidden or winded", function()
			refused({ requested = false }, "not asked")
			refused({ alive = false }, "not alive")
			refused({ frozen = true }, "frozen")
			refused({ hidden = true }, "hidden")
			refused({ stamina = false }, "winded")
		end)

		it("waits while crouched: the crouch stands up first, then the sprint starts from the walk", function()
			refused({ crouching = true }, "crouching")
		end)
	end)

	describe("offered", function()
		it("offers the button whenever the player is not hiding, hands full or not", function()
			expect(SprintRules.offered(false)).to.equal(true)
			expect(SprintRules.offered(true)).to.equal(false)
		end)
	end)
end
