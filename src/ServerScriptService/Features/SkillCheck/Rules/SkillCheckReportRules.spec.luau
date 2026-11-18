local SkillCheckReportRules = require(script.Parent.SkillCheckReportRules)

return function()
	describe("parse", function()
		it("accepts a ring id and a finite angle", function()
			local report = SkillCheckReportRules.parse(3, 271.5)
			expect(report).to.be.ok()
			expect(report.id).to.equal(3)
			expect(report.angle).to.equal(271.5)
		end)

		it("normalises the angle into [0, 360)", function()
			expect(SkillCheckReportRules.parse(1, -10).angle).to.equal(350)
			expect(SkillCheckReportRules.parse(1, 360).angle).to.equal(0)
		end)

		it("says why it refused", function()
			local report, reason = SkillCheckReportRules.parse(nil, nil)
			expect(report).to.equal(nil)
			expect(type(reason)).to.equal("string")
		end)

		it("refuses a missing, fractional, zero, negative or huge id", function()
			expect(SkillCheckReportRules.parse(nil, 0)).to.equal(nil)
			for _, id in { 1.5, 0, -1, 2 ^ 32, 0 / 0, math.huge, "1" } do
				expect(SkillCheckReportRules.parse(id, 0)).to.equal(nil)
			end
		end)

		it("refuses a missing or non-finite angle", function()
			expect(SkillCheckReportRules.parse(1, nil)).to.equal(nil)
			for _, angle in { 0 / 0, math.huge, -math.huge, "90" } do
				expect(SkillCheckReportRules.parse(1, angle)).to.equal(nil)
			end
		end)
	end)

	describe("window", function()
		-- Arrives at 100; judged from 99.75 to 100.6.
		local EARLY, LATE = 0.25, 0.6

		it("is open around the arrival", function()
			expect(SkillCheckReportRules.window(100, 100, EARLY, LATE)).to.equal("open")
			expect(SkillCheckReportRules.window(100.3, 100, EARLY, LATE)).to.equal("open")
			expect(SkillCheckReportRules.window(99.9, 100, EARLY, LATE)).to.equal("open")
		end)

		it("includes both edges", function()
			expect(SkillCheckReportRules.window(99.75, 100, EARLY, LATE)).to.equal("open")
			expect(SkillCheckReportRules.window(100.6, 100, EARLY, LATE)).to.equal("open")
		end)

		it("is early before the window", function()
			expect(SkillCheckReportRules.window(99.7, 100, EARLY, LATE)).to.equal("early")
			expect(SkillCheckReportRules.window(10, 100, EARLY, LATE)).to.equal("early")
		end)

		it("is late after the window", function()
			expect(SkillCheckReportRules.window(100.61, 100, EARLY, LATE)).to.equal("late")
			expect(SkillCheckReportRules.window(500, 100, EARLY, LATE)).to.equal("late")
		end)

		it("is late for a non-finite clock", function()
			expect(SkillCheckReportRules.window(0 / 0, 100, EARLY, LATE)).to.equal("late")
		end)
	end)
end
