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

	it("stamps GOAL DONE! and nothing else (owner P1 11-14: a game, not a newspaper)", function()
		local list = ShiftNoticeUtils.notices(running(), onBreak())
		expect(#list).to.equal(1)
		expect(list[1].text).to.equal("GOAL DONE!")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STAMP)
		expect(list[1].duration).to.equal(ShiftConstants.STAMP_SECONDS)
	end)

	it("says nothing when the break is over", function()
		expect(#ShiftNoticeUtils.notices(onBreak(), ShiftPhaseRules.advance(onBreak(), 180))).to.equal(0)
	end)

	it("says nothing at the overtime warning (the PA chime tells it)", function()
		expect(#ShiftNoticeUtils.notices(onBreak(), warning())).to.equal(0)
	end)

	it("stamps OVERTIME once, with no note", function()
		local list = ShiftNoticeUtils.notices(warning(), ShiftPhaseRules.advance(warning(), 190))
		expect(#list).to.equal(1)
		expect(list[1].text).to.equal("OVERTIME")
		expect(list[1].style).to.equal(ShiftConstants.TOAST_STAMP)
	end)

	it("says nothing when a pressure tier lands", function()
		local later = ShiftPhaseRules.advance(running(), 220)
		expect(later.tier > running().tier).to.equal(true)
		expect(#ShiftNoticeUtils.notices(running(), later)).to.equal(0)
	end)

	it("stays quiet outside a running shift", function()
		expect(#ShiftNoticeUtils.notices(ShiftPhaseRules.initial(350, "B"), running())).to.equal(0)
	end)

	it("only names styles the game registers", function()
		expect(ShiftConstants.TOAST_STYLES[ShiftConstants.TOAST_STAMP]).to.be.ok()
	end)

	describe("clock out", function()
		it("stamps only the truck's countdown; a punch alone says nothing (the HUD counts it)", function()
			local toast = ShiftNoticeUtils.truckLeaving()
			expect(toast.style).to.equal(ShiftConstants.TOAST_STAMP)
			expect(toast.text).to.equal("TRUCK LEAVES IN 30")
			expect(ShiftNoticeUtils.punched).to.equal(nil)
		end)
	end)
end
