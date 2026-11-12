local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingCoachRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingCoachRules)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)

local COACH = TrainingConstants.HUB_COACH
local LOOK = COACH.LOOK
local WAVE = COACH.WAVE

return function()
	describe("headTurn", function()
		it("looks straight ahead at a player straight ahead", function()
			local yaw, pitch = TrainingCoachRules.headTurn(Vector3.new(0, 0, -10))
			expect(yaw).to.be.near(0, 1e-6)
			expect(pitch).to.be.near(0, 1e-6)
		end)

		it("turns toward a player off to one side (forward is -Z; +yaw turns toward -X)", function()
			local yaw = TrainingCoachRules.headTurn(Vector3.new(-10, 0, -10))
			expect(yaw).to.be.near(math.rad(45), 1e-6)
			local other = TrainingCoachRules.headTurn(Vector3.new(10, 0, -10))
			expect(other).to.be.near(-math.rad(45), 1e-6)
		end)

		it("never turns further than a neck can", function()
			local yaw = TrainingCoachRules.headTurn(Vector3.new(-10, 0, -0.5))
			expect(yaw).to.be.near(math.rad(LOOK.MAX_YAW), 1e-6)
			local _, pitch = TrainingCoachRules.headTurn(Vector3.new(0, 30, -1))
			expect(pitch).to.be.near(math.rad(LOOK.MAX_PITCH), 1e-6)
			local _, down = TrainingCoachRules.headTurn(Vector3.new(0, -30, -1))
			expect(down).to.be.near(-math.rad(LOOK.MAX_PITCH), 1e-6)
		end)

		it("looks ahead again when the player is behind her or out of range", function()
			local yaw, pitch = TrainingCoachRules.headTurn(Vector3.new(1, 0, 10))
			expect(yaw).to.equal(0)
			expect(pitch).to.equal(0)
			local farYaw = TrainingCoachRules.headTurn(Vector3.new(-(LOOK.RANGE + 5), 0, -5))
			expect(farYaw).to.equal(0)
		end)

		it("looks ahead with nothing to look at", function()
			local yaw, pitch = TrainingCoachRules.headTurn(Vector3.zero)
			expect(yaw).to.equal(0)
			expect(pitch).to.equal(0)
		end)
	end)

	describe("ease", function()
		it("moves part of the way toward the target each frame, never past it", function()
			local stepped = TrainingCoachRules.ease(0, 1, 1 / 60)
			expect(stepped > 0 and stepped < 1).to.equal(true)
			expect(TrainingCoachRules.ease(0, 1, 100)).to.be.near(1, 1e-6)
			expect(TrainingCoachRules.ease(0.5, 0.5, 1 / 60)).to.equal(0.5)
		end)
	end)

	describe("nextWave", function()
		it("waits between WAVE.MIN and WAVE.MAX seconds", function()
			expect(TrainingCoachRules.nextWave(100, 0)).to.equal(100 + WAVE.MIN)
			expect(TrainingCoachRules.nextWave(100, 1)).to.equal(100 + WAVE.MAX)
			local mid = TrainingCoachRules.nextWave(100, 0.5)
			expect(mid > 100 + WAVE.MIN and mid < 100 + WAVE.MAX).to.equal(true)
		end)
	end)

	describe("wavesNow", function()
		it("waves when the player walks up", function()
			expect(TrainingCoachRules.wavesNow(WAVE.RADIUS - 1, false, 10, 50)).to.equal(true)
		end)

		it("does not wave again while they stand there", function()
			expect(TrainingCoachRules.wavesNow(WAVE.RADIUS - 1, true, 10, 50)).to.equal(false)
		end)

		it("waves now and then on her own, wherever the player is", function()
			expect(TrainingCoachRules.wavesNow(nil, false, 50, 50)).to.equal(true)
			expect(TrainingCoachRules.wavesNow(WAVE.RADIUS + 20, false, 49, 50)).to.equal(false)
		end)
	end)
end
