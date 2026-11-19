local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantClockFormulas = require(script.Parent.OccupantClockFormulas)

local CLOCK = OccupantConstants.CLOCK

local function run(clock, target, seconds)
	local dt = 1 / 60
	for _ = 1, math.round(seconds / dt) do
		clock = OccupantClockFormulas.step(clock, target, dt)
	end
	return clock
end

return function()
	describe("targetSpeed", function()
		it("keeps his hands still while he is calm or noticing", function()
			expect(OccupantClockFormulas.targetSpeed("patrol", "Calm")).to.equal(0)
			expect(OccupantClockFormulas.targetSpeed("investigate", "Noticing")).to.equal(0)
			expect(OccupantClockFormulas.targetSpeed("work", nil)).to.equal(0)
		end)

		it("spins his hands while he hunts (his face is the hunting one)", function()
			expect(OccupantClockFormulas.targetSpeed("chase", "Hunting")).to.equal(CLOCK.huntTurns)
			-- the sit-in's tip and the stare's check hunt too
			expect(OccupantClockFormulas.targetSpeed("work", "Hunting")).to.equal(CLOCK.huntTurns)
			expect(OccupantClockFormulas.targetSpeed("stare", "Hunting")).to.equal(CLOCK.huntTurns)
		end)

		it("spins them fastest on the catch", function()
			expect(OccupantClockFormulas.targetSpeed("catch", "Hunting")).to.equal(CLOCK.catchTurns)
			expect(OccupantClockFormulas.targetSpeed("catch", nil)).to.equal(CLOCK.catchTurns)
			expect(CLOCK.catchTurns > CLOCK.huntTurns).to.equal(true)
		end)
	end)

	describe("step", function()
		it("stays at rest at rest", function()
			local clock = OccupantClockFormulas.step(OccupantClockFormulas.REST, 0, 1 / 60)
			expect(clock.turns).to.equal(0)
			expect(clock.speed).to.equal(0)
		end)

		it("spins up toward the target speed, not in one jump", function()
			local clock = OccupantClockFormulas.step(OccupantClockFormulas.REST, CLOCK.huntTurns, 1 / 60)
			expect(clock.speed > 0).to.equal(true)
			expect(clock.speed < CLOCK.huntTurns).to.equal(true)
			clock = run(clock, CLOCK.huntTurns, 2)
			expect(clock.speed).to.be.near(CLOCK.huntTurns, 1e-6)
			expect(clock.turns > 1).to.equal(true)
		end)

		it("winds down and settles the minute hand back on 12 (a whole turn)", function()
			local clock = run(OccupantClockFormulas.REST, CLOCK.catchTurns, 1.37)
			clock = run(clock, 0, 6)
			expect(clock.speed).to.equal(0)
			expect(clock.turns % 1).to.be.near(0, 1e-9)
			-- and stays there
			local after = run(clock, 0, 1)
			expect(after.turns).to.equal(clock.turns)
		end)

		it("only ever winds forward, like a clock", function()
			local clock = run(OccupantClockFormulas.REST, CLOCK.huntTurns, 0.73)
			local last = clock.turns
			for _ = 1, 600 do
				clock = OccupantClockFormulas.step(clock, 0, 1 / 60)
				expect(clock.turns >= last).to.equal(true)
				last = clock.turns
			end
		end)

		it("ignores a non-positive step", function()
			local clock = { turns = 0.4, speed = 1 }
			local same = OccupantClockFormulas.step(clock, 0, 0)
			expect(same.turns).to.equal(0.4)
			expect(same.speed).to.equal(1)
		end)
	end)

	describe("angles", function()
		it("puts both hands at their painted rest (no extra turn) at rest", function()
			local minute, hour = OccupantClockFormulas.angles(OccupantClockFormulas.REST)
			expect(minute).to.equal(0)
			expect(hour).to.equal(0)
		end)

		it("turns the hour hand one twelfth as fast as the minute hand", function()
			local minute, hour = OccupantClockFormulas.angles({ turns = 2.25, speed = 0 })
			expect(minute).to.be.near(90, 1e-9)
			expect(hour).to.be.near(2.25 * 30, 1e-9)
		end)

		it("keeps both angles within one turn", function()
			local minute, hour = OccupantClockFormulas.angles({ turns = 31.5, speed = 0 })
			expect(minute).to.be.near(180, 1e-9)
			expect(hour >= 0 and hour < 360).to.equal(true)
		end)
	end)
end
