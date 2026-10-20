local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftClockOutSystem = require(script.Parent.ShiftClockOutSystem)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftPhaseRules = require(ServerScriptService.Features.Shift.Rules.ShiftPhaseRules)
local ShiftClockOutRules = require(ServerScriptService.Features.Shift.Rules.ShiftClockOutRules)

-- A fake crew member (the system reads UserId and DisplayName).
local function member(userId)
	return { UserId = userId, DisplayName = `Crew {userId}` }
end

-- A running shift, a crew of `size` (userIds 1..size), and fakes for every effect. `log.out[userId] = true` catches a
-- member; `log.outside[userId] = true` walks a member off the truck; `log.time` is the clock.
local function harness(size)
	local log = {
		time = 200,
		state = ShiftPhaseRules.follow(
			ShiftPhaseRules.initial(350, "B"),
			{ phase = "running", round = 1, endsAt = 620 },
			100
		),
		crew = {},
		out = {},
		knocked = {},
		outside = {},
		boarded = {},
		toasts = {},
		strangers = {},
	}
	for userId = 1, size do
		table.insert(log.crew, member(userId))
	end
	log.system = ShiftClockOutSystem.new({
		getState = function()
			return log.state
		end,
		setState = function(nextState)
			log.state = nextState
		end,
		now = function()
			return log.time
		end,
		crew = function()
			return log.crew
		end,
		eligible = function(player)
			return not log.strangers[player.UserId]
		end,
		isOut = function(player)
			return log.out[player.UserId] == true
		end,
		isKnockedOut = function(player)
			return log.knocked[player.UserId] == true
		end,
		board = function(player, index)
			table.insert(log.boarded, { userId = player.UserId, index = index })
			log.outside[player.UserId] = nil
		end,
		aboard = function(player)
			return not log.outside[player.UserId]
		end,
		announce = function(toasts)
			for _, toast in toasts do
				table.insert(log.toasts, toast.text)
			end
		end,
	})
	return log
end

local function said(log, needle)
	for _, text in log.toasts do
		if string.find(text, needle, 1, true) then
			return true
		end
	end
	return false
end

return function()
	describe("punch", function()
		it("ends a solo shift at once: the truck leaves now, no countdown", function()
			local log = harness(1)
			expect(log.system.punch(log.crew[1])).to.equal(true)
			expect(log.state.sub).to.equal("clockout")
			expect(log.state.clockOutAt).to.equal(200)
			expect(ShiftPhaseRules.tick(log.state, 200, 1)).to.equal("endShift")
			expect(said(log, "TRUCK LEAVES")).to.equal(false)
		end)

		it("moves the punched member into the truck, at their crew spot", function()
			local log = harness(3)
			log.system.punch(log.crew[2])
			expect(#log.boarded).to.equal(1)
			expect(log.boarded[1].userId).to.equal(2)
			expect(log.boarded[1].index).to.equal(2)
		end)

		it("tells everyone who punched and the count, and waits below half", function()
			local log = harness(3)
			log.system.punch(log.crew[1])
			expect(said(log, "Crew 1 clocked out: 1/3")).to.equal(true)
			expect(log.state.sub).to.equal("normal")
			expect(log.state.crewIn).to.equal(3)
		end)

		it("starts the 30 s truck countdown at half (1 of 2), announced after the punch", function()
			local log = harness(2)
			log.system.punch(log.crew[1])
			expect(log.state.sub).to.equal("clockout")
			expect(log.state.clockOutAt).to.equal(200 + ShiftConstants.TRUCK_LEAVES_SECONDS)
			expect(said(log, "1/2")).to.equal(true)
			expect(log.toasts[#log.toasts - 1]).to.equal("TRUCK LEAVES IN 30")
		end)

		it("starts the countdown at 2 of 4, and leaves once all 4 punched", function()
			local log = harness(4)
			log.system.punch(log.crew[1])
			expect(log.state.sub).to.equal("normal")
			log.system.punch(log.crew[2])
			expect(log.state.sub).to.equal("clockout")
			log.time = 210
			log.system.punch(log.crew[3])
			expect(log.state.clockOutAt).to.equal(200 + ShiftConstants.TRUCK_LEAVES_SECONDS)
			log.system.punch(log.crew[4])
			expect(log.state.clockOutAt).to.equal(210)
		end)

		it("refuses a second punch, someone outside the crew, and a punch outside a run", function()
			local log = harness(3)
			expect(log.system.punch(log.crew[1])).to.equal(true)
			expect(log.system.punch(log.crew[1])).to.equal(false)
			log.strangers[9] = true
			expect(log.system.punch(member(9))).to.equal(false)
			log.state = ShiftPhaseRules.initial(350, "B")
			expect(log.system.punch(log.crew[2])).to.equal(false)
		end)
	end)

	describe("settle", function()
		it("leaves at once when the last one inside is knocked out during the countdown", function()
			local log = harness(2)
			log.system.punch(log.crew[1])
			log.time = 215
			log.out[2] = true
			log.knocked[2] = true
			log.system.settle()
			expect(log.state.clockOutAt).to.equal(215)
			expect(log.state.crewIn).to.equal(1)
		end)

		it("keeps waiting, not leaving, when the last one inside is only caught and will be back", function()
			local log = harness(2)
			log.out[2] = true
			log.system.punch(log.crew[1])
			expect(log.state.clockOutAt).to.equal(nil)
			log.time = 215
			log.system.settle()
			expect(log.state.clockOutAt).to.equal(nil)
		end)

		it("leaves at once when the last one inside leaves the game", function()
			local log = harness(3)
			log.system.punch(log.crew[1])
			log.system.punch(log.crew[2])
			log.time = 220
			table.remove(log.crew, 3)
			log.system.settle()
			expect(log.state.clockOutAt).to.equal(220)
		end)

		it("starts the countdown when a catch brings the punched share to half", function()
			local log = harness(3)
			log.system.punch(log.crew[1])
			expect(log.state.sub).to.equal("normal")
			log.out[3] = true
			log.system.settle()
			expect(log.state.sub).to.equal("clockout")
			expect(log.state.clockOutAt).to.equal(200 + ShiftConstants.TRUCK_LEAVES_SECONDS)
			expect(said(log, "TRUCK LEAVES IN 30")).to.equal(true)
		end)
	end)

	describe("hold", function()
		it("puts a punched member who walks off the truck back in it", function()
			local log = harness(3)
			log.system.punch(log.crew[1])
			log.outside[1] = true
			log.outside[2] = true
			log.system.hold()
			expect(#log.boarded).to.equal(2)
			expect(log.boarded[2].userId).to.equal(1)
		end)
	end)

	describe("working", function()
		it("is a crew member who has not punched (the overtime sheet's signers)", function()
			local log = harness(2)
			log.system.punch(log.crew[1])
			expect(log.system.working(log.crew[1])).to.equal(false)
			expect(log.system.working(log.crew[2])).to.equal(true)
			expect(log.system.isPunched(log.crew[1])).to.equal(true)
			expect(ShiftClockOutRules.isPunched(log.state, 1)).to.equal(true)
		end)
	end)
end
