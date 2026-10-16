local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantMenaceFormulas = require(script.Parent.OccupantMenaceFormulas)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local CREW = { tier = 0, solo = false, overtime = false }
local SOLO = { tier = 0, solo = true, overtime = false }

return function()
	describe("step", function()
		it("rises while he chases", function()
			local after = OccupantMenaceFormulas.step(10, 1, { chasing = true, engaged = false, near = false })
			expect(after).to.equal(10 + OccupantConstants.MENACE_CHASE)
		end)
		it("adds up chasing, engaging and being near", function()
			local after = OccupantMenaceFormulas.step(0, 2, { chasing = true, engaged = true, near = true })
			expect(after).to.equal(
				2 * (OccupantConstants.MENACE_CHASE + OccupantConstants.MENACE_STARE + OccupantConstants.MENACE_NEAR)
			)
		end)
		it("falls when nothing is happening, never below 0", function()
			expect(OccupantMenaceFormulas.step(10, 1, { chasing = false, engaged = false, near = false })).to.equal(
				10 - OccupantConstants.MENACE_DECAY
			)
			expect(OccupantMenaceFormulas.step(1, 5, { chasing = false, engaged = false, near = false })).to.equal(0)
		end)
		it("is capped at MENACE_MAX", function()
			expect(OccupantMenaceFormulas.step(99, 10, { chasing = true, engaged = false, near = false })).to.equal(
				OccupantConstants.MENACE_MAX
			)
		end)
	end)

	describe("bump", function()
		it("adds a lump, capped", function()
			expect(OccupantMenaceFormulas.bump(10, OccupantConstants.MENACE_CATCH)).to.equal(
				10 + OccupantConstants.MENACE_CATCH
			)
			expect(OccupantMenaceFormulas.bump(90, 50)).to.equal(OccupantConstants.MENACE_MAX)
		end)
	end)

	describe("full", function()
		it("is full at the max", function()
			expect(OccupantMenaceFormulas.full(OccupantConstants.MENACE_MAX)).to.equal(true)
			expect(OccupantMenaceFormulas.full(OccupantConstants.MENACE_MAX - 1)).to.equal(false)
		end)
	end)

	describe("steerInterval", function()
		it("is longer solo than with a crew", function()
			expect(OccupantMenaceFormulas.steerInterval(SOLO)).to.equal(OccupantConstants.STEER_SOLO)
			expect(OccupantMenaceFormulas.steerInterval(CREW)).to.equal(OccupantConstants.STEER_CREW)
		end)
		it("shortens per tier", function()
			expect(OccupantMenaceFormulas.steerInterval({ tier = 2, solo = false, overtime = false })).to.equal(
				OccupantConstants.STEER_CREW - 2 * OccupantConstants.STEER_PER_TIER
			)
		end)
		it("uses the overtime interval in overtime", function()
			expect(OccupantMenaceFormulas.steerInterval({ tier = 2, solo = false, overtime = true })).to.equal(
				OccupantConstants.STEER_OVERTIME_CREW
			)
			expect(OccupantMenaceFormulas.steerInterval({ tier = 2, solo = true, overtime = true })).to.equal(
				OccupantConstants.STEER_OVERTIME_SOLO
			)
		end)
	end)

	describe("breather", function()
		it("rolls within the crew range", function()
			local range = OccupantConstants.BREATHER_CREW
			expect(OccupantMenaceFormulas.breather(CREW, 0)).to.equal(range.min)
			expect(OccupantMenaceFormulas.breather(CREW, 1)).to.equal(range.max)
		end)
		it("is longer solo", function()
			expect(OccupantMenaceFormulas.breather(SOLO, 0)).to.equal(OccupantConstants.BREATHER_SOLO.min)
		end)
		it("shortens per tier and is short in overtime", function()
			expect(OccupantMenaceFormulas.breather({ tier = 1, solo = false, overtime = false }, 0)).to.equal(
				OccupantConstants.BREATHER_CREW.min - OccupantConstants.BREATHER_PER_TIER
			)
			expect(OccupantMenaceFormulas.breather({ tier = 2, solo = false, overtime = true }, 1)).to.equal(
				OccupantConstants.BREATHER_OVERTIME.max
			)
		end)
	end)

	describe("within", function()
		it("maps a roll into a range", function()
			expect(OccupantMenaceFormulas.within({ min = 10, max = 20 }, 0.5)).to.equal(15)
			expect(OccupantMenaceFormulas.within({ min = 10, max = 20 }, 2)).to.equal(20)
		end)
	end)
end
