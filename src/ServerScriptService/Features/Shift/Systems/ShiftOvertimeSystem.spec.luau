local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftOvertimeSystem = require(script.Parent.ShiftOvertimeSystem)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local ShiftPhaseRules = require(ServerScriptService.Features.Shift.Rules.ShiftPhaseRules)

local PLAYER = { UserId = 9021, Name = "OvertimeSpecPlayer", DisplayName = "Overtime Spec" }

local function running()
	return ShiftPhaseRules.follow(
		ShiftPhaseRules.initial(350, "B"),
		{ phase = "running", round = 1, endsAt = 520 },
		100
	)
end

-- A system over a fake shift: `state` is what getState returns; every setState is recorded.
local function harness(state, eligible, reaches)
	local log = { state = state, sets = {}, announced = {}, enabled = {} }
	local sheet = Instance.new("Part")
	log.system = ShiftOvertimeSystem.new({
		getState = function()
			return log.state
		end,
		setState = function(nextState)
			log.state = nextState
			table.insert(log.sets, nextState)
		end,
		eligible = function()
			return eligible ~= false
		end,
		now = function()
			return 160
		end,
		changed = nil,
		sheet = function()
			return sheet
		end,
		setEnabled = function(target, enabled)
			table.insert(log.enabled, { target = target, enabled = enabled })
		end,
		announce = function(text)
			table.insert(log.announced, text)
		end,
		reaches = function()
			return reaches ~= false
		end,
	})
	log.sheet = sheet
	return log
end

return function()
	it("registers the overtime sheet's prompt as a held, deliberate choice", function()
		expect(InteractionRegistry.has(ShiftConstants.OVERTIME_KIND)).to.equal(true)
		local def = InteractionRegistry.get(ShiftConstants.OVERTIME_KIND)
		expect(def.actionText).to.equal("Start overtime")
		expect(def.holdDuration).to.equal(ShiftConstants.OVERTIME_HOLD)
		expect(ShiftConstants.OVERTIME_HOLD > 0).to.equal(true)
		expect(def.maxDistance).to.equal(ShiftConstants.PAPERWORK_DISTANCE)
	end)

	describe("sign", function()
		it("begins overtime for a crew member who reaches the sheet", function()
			local log = harness(ShiftPhaseRules.markQuota(running(), 350, 150))
			expect(log.system.sign(PLAYER, log.sheet)).to.equal(true)
			expect(log.state.stage).to.equal("warning")
		end)

		it("refuses a crew member who cannot reach it (carrying, or outside the box)", function()
			local log = harness(ShiftPhaseRules.markQuota(running(), 350, 150), true, false)
			expect(log.system.sign(PLAYER, log.sheet)).to.equal(false)
			expect(#log.sets).to.equal(0)
			expect(#log.announced).to.equal(0)
		end)
	end)

	describe("begin", function()
		it("starts the overtime warning for the crew and says who signed", function()
			local log = harness(ShiftPhaseRules.markQuota(running(), 350, 150))
			expect(log.system.begin(PLAYER)).to.equal(true)
			expect(#log.sets).to.equal(1)
			expect(log.state.stage).to.equal("warning")
			expect(log.state.stageEndsAt).to.equal(160 + ShiftConstants.WARNING_SECONDS)
			expect(log.announced[1]).to.equal("Overtime Spec signed the overtime sheet!")
		end)

		it("refuses a player outside the crew without touching the shift", function()
			local log = harness(ShiftPhaseRules.markQuota(running(), 350, 150), false)
			expect(log.system.begin(PLAYER)).to.equal(false)
			expect(#log.sets).to.equal(0)
			expect(#log.announced).to.equal(0)
		end)

		it("refuses before the quota is met, and a second signature", function()
			local early = harness(running())
			expect(early.system.begin(PLAYER)).to.equal(false)
			expect(#early.sets).to.equal(0)
			local twice = harness(ShiftPhaseRules.markQuota(running(), 350, 150))
			expect(twice.system.begin(PLAYER)).to.equal(true)
			expect(twice.system.begin(PLAYER)).to.equal(false)
			expect(#twice.sets).to.equal(1)
		end)
	end)

	describe("sync", function()
		it("shows the sheet's prompt exactly while overtime may start", function()
			local log = harness(running())
			log.system.sync()
			expect(log.enabled[1].target).to.equal(log.sheet)
			expect(log.enabled[1].enabled).to.equal(false)
			log.state = ShiftPhaseRules.markQuota(running(), 350, 150)
			log.system.sync()
			expect(log.enabled[2].enabled).to.equal(true)
			log.state = ShiftPhaseRules.startOvertime(log.state, 160)
			log.system.sync()
			expect(log.enabled[3].enabled).to.equal(false)
		end)
	end)
end
