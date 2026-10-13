local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftNoticeUtils = require(script.Parent.ShiftNoticeUtils)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftPhaseRules = require(ServerScriptService.Features.Shift.Rules.ShiftPhaseRules)

local function running()
	return ShiftPhaseRules.follow(
		ShiftPhaseRules.initial(350, "B"),
		{ phase = "running", round = 1, endsAt = 520 },
		100
	)
end

local function onBreak()
	return ShiftPhaseRules.markQuota(running(), 350, 150)
end

-- The crew started overtime at 160.
local function warning()
	return ShiftPhaseRules.startOvertime(onBreak(), 160)
end

return function()
	it("says nothing when nothing changed", function()
		expect(#ShiftNoticeUtils.notices(running(), running())).to.equal(0)
	end)

	it("stamps QUOTA MET, then the company's notice, then the choice", function()
		local list = ShiftNoticeUtils.notices(running(), onBreak())
		expect(#list).to.equal(3)
		expect(list[1].text).to.equal("QUOTA MET")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STAMP)
		expect(list[1].duration).to.equal(ShiftConstants.STAMP_SECONDS)
		expect(list[2].style).to.equal(ShiftConstants.TOAST_STICKY)
		expect(list[2].text).to.equal(
			"Clearance threshold reached. Optional recovery remains available. Extended-site coverage is not guaranteed."
		)
		expect(list[2].duration).to.equal(ShiftConstants.NOTICE_SECONDS)
		expect(list[3].style).to.equal(ShiftConstants.TOAST_STICKY)
		expect(list[3].text).to.equal(
			"The Manager is on break. Clock out at the truck to leave, or start overtime there: assets ×1.5, faster Manager."
		)
	end)

	it("says when the break is over, and that overtime has not started", function()
		local list = ShiftNoticeUtils.notices(onBreak(), ShiftPhaseRules.advance(onBreak(), 180))
		expect(#list).to.equal(1)
		expect(list[1].text).to.equal("Break's over: the Manager is back on the floor. Overtime is still your call.")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STICKY)
	end)

	it("warns before overtime on a sticky note, with time to bank and regroup", function()
		local list = ShiftNoticeUtils.notices(onBreak(), warning())
		expect(#list).to.equal(1)
		expect(list[1].text).to.equal("Overtime in 0:30: assets ×1.5. Bank your cargo and regroup.")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STICKY)
	end)

	it("stamps OVERTIME once, with its note and without a tier note", function()
		local list = ShiftNoticeUtils.notices(warning(), ShiftPhaseRules.advance(warning(), 190))
		expect(#list).to.equal(2)
		expect(list[1].text).to.equal("OVERTIME")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STAMP)
		expect(list[2].style).to.equal(ShiftConstants.TOAST_STICKY)
		expect(list[2].text).to.equal("Assets ×1.5 until the clock runs out. The Manager is faster now.")
	end)

	it("notes each pressure tier on a sticky note", function()
		local list = ShiftNoticeUtils.notices(running(), ShiftPhaseRules.advance(running(), 220))
		expect(#list).to.equal(1)
		expect(list[1].text).to.equal("You hear the Manager pacing faster…")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STICKY)
	end)

	it("holds the tier note back during the break", function()
		local early = ShiftPhaseRules.markQuota(running(), 350, 215)
		local later = ShiftPhaseRules.advance(early, 225)
		expect(later.tier).to.equal(1)
		expect(later.stage).to.equal("break")
		expect(#ShiftNoticeUtils.notices(early, later)).to.equal(0)
	end)

	it("says only that the break is over when a tier lands in the same step", function()
		local early = ShiftPhaseRules.markQuota(running(), 350, 190)
		local back = ShiftPhaseRules.advance(early, 220)
		expect(back.stage).to.equal("normal")
		expect(back.tier).to.equal(1)
		local list = ShiftNoticeUtils.notices(early, back)
		expect(#list).to.equal(1)
		expect(list[1].text).to.equal("Break's over: the Manager is back on the floor. Overtime is still your call.")
	end)

	it("holds the tier note back during the warning", function()
		local warned = ShiftPhaseRules.startOvertime(ShiftPhaseRules.markQuota(running(), 350, 170), 200)
		local later = ShiftPhaseRules.advance(warned, 225)
		expect(later.stage).to.equal("warning")
		expect(later.tier).to.equal(1)
		expect(#ShiftNoticeUtils.notices(warned, later)).to.equal(0)
	end)

	it("stays quiet outside a running shift", function()
		expect(#ShiftNoticeUtils.notices(ShiftPhaseRules.initial(350, "B"), running())).to.equal(0)
	end)

	it("only names styles the game registers", function()
		expect(ShiftConstants.TOAST_STYLES[ShiftConstants.TOAST_STICKY]).to.be.ok()
		expect(ShiftConstants.TOAST_STYLES[ShiftConstants.TOAST_STAMP]).to.be.ok()
	end)
end
