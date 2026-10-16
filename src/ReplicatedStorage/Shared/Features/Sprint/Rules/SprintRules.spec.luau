local SprintRules = require(script.Parent.SprintRules)

local function input(extra)
	local value = { requested = true, alive = true, frozen = false, hidden = false, carrying = false, stamina = true }
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

		it("sprints an empty-handed, living, free player who asks and has the stamina", function()
			expect(SprintRules.canSprint(input())).to.equal(true)
		end)

		it("never sprints while carrying anything", function()
			refused({ carrying = true }, "hands full")
		end)

		it("refuses without asking, dead, frozen, hidden or winded", function()
			refused({ requested = false }, "not asked")
			refused({ alive = false }, "not alive")
			refused({ frozen = true }, "frozen")
			refused({ hidden = true }, "hidden")
			refused({ stamina = false }, "winded")
		end)
	end)

	describe("offered", function()
		it("offers the button only with empty hands and out of hiding", function()
			expect(SprintRules.offered(false, false)).to.equal(true)
			expect(SprintRules.offered(true, false)).to.equal(false)
			expect(SprintRules.offered(false, true)).to.equal(false)
		end)
	end)
end
