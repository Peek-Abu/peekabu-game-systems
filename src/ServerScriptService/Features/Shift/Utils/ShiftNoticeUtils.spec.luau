local ServerScriptService = game:GetService("ServerScriptService")

local ShiftNoticeUtils = require(script.Parent.ShiftNoticeUtils)
local ShiftPhaseRules = require(ServerScriptService.Features.Shift.Rules.ShiftPhaseRules)

local function running()
	return ShiftPhaseRules.follow(
		ShiftPhaseRules.initial(350, "B"),
		{ phase = "running", round = 1, endsAt = 520 },
		100
	)
end

local function texts(list)
	local result = {}
	for _, notice in list do
		table.insert(result, notice.text)
	end
	return result
end

return function()
	it("says nothing when nothing changed", function()
		expect(#ShiftNoticeUtils.notices(running(), running())).to.equal(0)
	end)

	it("announces the quota and Harlow's break", function()
		local list = texts(ShiftNoticeUtils.notices(running(), ShiftPhaseRules.markQuota(running(), 350, 150)))
		expect(#list).to.equal(1)
		expect(string.find(list[1], "QUOTA MET", 1, true) ~= nil).to.equal(true)
		expect(string.find(list[1], "break", 1, true) ~= nil).to.equal(true)
	end)

	it("warns before overtime in the spec's words", function()
		local onBreak = ShiftPhaseRules.markQuota(running(), 350, 150)
		local list = texts(ShiftNoticeUtils.notices(onBreak, ShiftPhaseRules.advance(onBreak, 180)))
		expect(#list).to.equal(1)
		expect(list[1]).to.equal("Overtime in 0:30, salvage ×1.5")
	end)

	it("announces overtime once, without a second tier note", function()
		local warning = ShiftPhaseRules.advance(ShiftPhaseRules.markQuota(running(), 350, 150), 180)
		local list = texts(ShiftNoticeUtils.notices(warning, ShiftPhaseRules.advance(warning, 210)))
		expect(#list).to.equal(1)
		expect(string.find(list[1], "OVERTIME", 1, true) ~= nil).to.equal(true)
	end)

	it("notes each pressure tier", function()
		local list = texts(ShiftNoticeUtils.notices(running(), ShiftPhaseRules.advance(running(), 220)))
		expect(#list).to.equal(1)
		expect(list[1]).to.equal("You hear Harlow pacing faster…")
	end)

	it("holds the tier note back during the break", function()
		local onBreak = ShiftPhaseRules.markQuota(running(), 350, 215)
		local later = ShiftPhaseRules.advance(onBreak, 225)
		expect(later.tier).to.equal(1)
		expect(later.stage).to.equal("break")
		expect(#ShiftNoticeUtils.notices(onBreak, later)).to.equal(0)
	end)

	it("says only the warning when a tier lands in the same step", function()
		local onBreak = ShiftPhaseRules.markQuota(running(), 350, 190)
		local warning = ShiftPhaseRules.advance(onBreak, 220)
		expect(warning.stage).to.equal("warning")
		expect(warning.tier).to.equal(1)
		local list = texts(ShiftNoticeUtils.notices(onBreak, warning))
		expect(#list).to.equal(1)
		expect(list[1]).to.equal("Overtime in 0:30, salvage ×1.5")
	end)

	it("holds the tier note back during the warning", function()
		local warning = ShiftPhaseRules.advance(ShiftPhaseRules.markQuota(running(), 350, 140), 170)
		local later = ShiftPhaseRules.advance(warning, 225)
		expect(later.stage).to.equal("warning")
		expect(later.tier).to.equal(1)
		expect(#ShiftNoticeUtils.notices(warning, later)).to.equal(0)
	end)

	it("stays quiet outside a running shift", function()
		local lobby = ShiftPhaseRules.initial(350, "B")
		expect(#ShiftNoticeUtils.notices(lobby, running())).to.equal(0)
	end)
end
