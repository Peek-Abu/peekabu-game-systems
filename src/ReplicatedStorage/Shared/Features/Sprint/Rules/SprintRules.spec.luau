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
			expect(SprintRules.offered(false, false)).to.equal(true)
			expect(SprintRules.offered(true, false)).to.equal(false)
		end)

		it("drops the SPRINT button while the stick runs (a far push is the run)", function()
			expect(SprintRules.offered(false, true)).to.equal(false)
			expect(SprintRules.offered(true, true)).to.equal(false)
		end)
	end)

	describe("stickRun", function()
		local SETTINGS = { enabled = true, threshold = 0.9, release = 0.8 }

		it("runs once the stick is pushed past the threshold", function()
			expect(SprintRules.stickRun(0.5, false, false, SETTINGS)).to.equal(false)
			expect(SprintRules.stickRun(0.89, false, false, SETTINGS)).to.equal(false)
			expect(SprintRules.stickRun(0.9, false, false, SETTINGS)).to.equal(true)
			expect(SprintRules.stickRun(1, false, false, SETTINGS)).to.equal(true)
		end)

		it("keeps running until the push falls under the release, so it never flickers at the edge", function()
			expect(SprintRules.stickRun(0.85, false, true, SETTINGS)).to.equal(true)
			expect(SprintRules.stickRun(0.8, false, true, SETTINGS)).to.equal(true)
			expect(SprintRules.stickRun(0.79, false, true, SETTINGS)).to.equal(false)
		end)

		it("never runs from a crouch: a far push keeps sneaking instead of standing up", function()
			expect(SprintRules.stickRun(1, true, false, SETTINGS)).to.equal(false)
			expect(SprintRules.stickRun(1, true, true, SETTINGS)).to.equal(false)
		end)

		it("does nothing while switched off", function()
			local off = { enabled = false, threshold = 0.9, release = 0.8 }
			expect(SprintRules.stickRun(1, false, false, off)).to.equal(false)
			expect(SprintRules.stickRun(1, false, true, off)).to.equal(false)
		end)

		it("ships switched on, with a release under the threshold", function()
			local SprintConstants = require(script.Parent.Parent.Data.SprintConstants)
			local stick = SprintConstants.STICK_RUN
			expect(stick.threshold > stick.release).to.equal(true)
			expect(stick.threshold <= 1).to.equal(true)
			expect(stick.release > 0).to.equal(true)
		end)
	end)
end
