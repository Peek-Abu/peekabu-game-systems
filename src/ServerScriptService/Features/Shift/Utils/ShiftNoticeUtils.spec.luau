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

local function warning()
	return ShiftPhaseRules.advance(onBreak(), 180)
end

return function()
	it("says nothing when nothing changed", function()
		expect(#ShiftNoticeUtils.notices(running(), running())).to.equal(0)
	end)

	it("stamps QUOTA MET, then a sticky note about Harlow's break", function()
		local list = ShiftNoticeUtils.notices(running(), onBreak())
		expect(#list).to.equal(2)
		expect(list[1].text).to.equal("QUOTA MET")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STAMP)
		expect(list[1].duration).to.equal(ShiftConstants.STAMP_SECONDS)
		expect(list[2].style).to.equal(ShiftConstants.TOAST_STICKY)
		expect(list[2].text).to.equal("Mr. Harlow is on his break for 0:30. Regroup and bank.")
		expect(list[2].duration).to.equal(ShiftConstants.NOTICE_SECONDS)
	end)

	it("warns before overtime on a sticky note, in the spec's words", function()
		local list = ShiftNoticeUtils.notices(onBreak(), warning())
		expect(#list).to.equal(1)
		expect(list[1].text).to.equal("Overtime in 0:30, salvage ×1.5")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STICKY)
	end)

	it("stamps OVERTIME once, with its note and without a tier note", function()
		local list = ShiftNoticeUtils.notices(warning(), ShiftPhaseRules.advance(warning(), 210))
		expect(#list).to.equal(2)
		expect(list[1].text).to.equal("OVERTIME")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STAMP)
		expect(list[2].style).to.equal(ShiftConstants.TOAST_STICKY)
		expect(string.find(list[2].text, "×1.5", 1, true) ~= nil).to.equal(true)
	end)

	it("notes each pressure tier on a sticky note", function()
		local list = ShiftNoticeUtils.notices(running(), ShiftPhaseRules.advance(running(), 220))
		expect(#list).to.equal(1)
		expect(list[1].text).to.equal("You hear Harlow pacing faster…")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STICKY)
	end)

	it("holds the tier note back during the break", function()
		local early = ShiftPhaseRules.markQuota(running(), 350, 215)
		local later = ShiftPhaseRules.advance(early, 225)
		expect(later.tier).to.equal(1)
		expect(later.stage).to.equal("break")
		expect(#ShiftNoticeUtils.notices(early, later)).to.equal(0)
	end)

	it("says only the warning when a tier lands in the same step", function()
		local early = ShiftPhaseRules.markQuota(running(), 350, 190)
		local warned = ShiftPhaseRules.advance(early, 220)
		expect(warned.stage).to.equal("warning")
		expect(warned.tier).to.equal(1)
		local list = ShiftNoticeUtils.notices(early, warned)
		expect(#list).to.equal(1)
		expect(list[1].text).to.equal("Overtime in 0:30, salvage ×1.5")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STICKY)
	end)

	it("holds the tier note back during the warning", function()
		local warned = ShiftPhaseRules.advance(ShiftPhaseRules.markQuota(running(), 350, 170), 200)
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
