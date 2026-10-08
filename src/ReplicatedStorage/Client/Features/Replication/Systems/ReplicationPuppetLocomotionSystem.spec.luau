local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationPuppetLocomotionSystem =
	require(ReplicatedStorage.Client.Features.Replication.Systems.ReplicationPuppetLocomotionSystem)

local S = Enum.HumanoidStateType

local function step(tracker, state, velocity)
	return ReplicationPuppetLocomotionSystem.step(tracker, state.Value, velocity or Vector3.zero)
end

return function()
	describe("state to event", function()
		it("maps each owner state to the event its Humanoid would fire", function()
			local cases = {
				{ S.Running, "running" },
				{ S.RunningNoPhysics, "running" },
				{ S.Landed, "running" },
				{ S.Jumping, "jumping" },
				{ S.Freefall, "freefall" },
				{ S.Climbing, "climbing" },
				{ S.Swimming, "swimming" },
				{ S.Seated, "seated" },
				{ S.GettingUp, "gettingUp" },
				{ S.PlatformStanding, "platformStanding" },
				{ S.Dead, "died" },
			}
			for _, case in cases do
				local event = step(ReplicationPuppetLocomotionSystem.new(), case[1])
				expect(event).to.equal(case[2])
			end
		end)

		it("sends nothing for states with no locomotion pose, so the current pose holds", function()
			for _, state in { S.Physics, S.FallingDown, S.Ragdoll } do
				expect(step(ReplicationPuppetLocomotionSystem.new(), state)).to.equal(nil)
			end
			expect(ReplicationPuppetLocomotionSystem.step(ReplicationPuppetLocomotionSystem.new(), 29, Vector3.zero)).to.equal(
				nil
			)
		end)
	end)

	describe("speed", function()
		it("carries horizontal speed running, vertical climbing and full speed swimming", function()
			local _, running = step(ReplicationPuppetLocomotionSystem.new(), S.Running, Vector3.new(3, 9, 4))
			expect(running).to.be.near(5, 1e-6)
			local _, climbing = step(ReplicationPuppetLocomotionSystem.new(), S.Climbing, Vector3.new(1, -6, 0))
			expect(climbing).to.be.near(6, 1e-6)
			local _, swimming = step(ReplicationPuppetLocomotionSystem.new(), S.Swimming, Vector3.new(2, 3, 6))
			expect(swimming).to.be.near(7, 1e-6)
			local _, jumping = step(ReplicationPuppetLocomotionSystem.new(), S.Jumping, Vector3.new(0, 50, 0))
			expect(jumping).to.equal(nil)
		end)
	end)

	describe("send on change only", function()
		it("sends an event once, then again only when it changes", function()
			local tracker = ReplicationPuppetLocomotionSystem.new()
			expect(step(tracker, S.Freefall)).to.equal("freefall")
			expect(step(tracker, S.Freefall)).to.equal(nil)
			expect(step(tracker, S.Running, Vector3.new(10, 0, 0))).to.equal("running")
		end)

		it("re-sends running when the speed moves by at least 5 % of the last sent speed", function()
			local tracker = ReplicationPuppetLocomotionSystem.new()
			step(tracker, S.Running, Vector3.new(10, 0, 0))
			expect(step(tracker, S.Running, Vector3.new(10.4, 0, 0))).to.equal(nil)
			local event, speed = step(tracker, S.Running, Vector3.new(10.6, 0, 0))
			expect(event).to.equal("running")
			expect(speed).to.be.near(10.6, 1e-6)
		end)

		it("re-sends from a standstill after a step of at least 0.25 studs/s", function()
			local tracker = ReplicationPuppetLocomotionSystem.new()
			step(tracker, S.Running, Vector3.zero)
			expect(step(tracker, S.Running, Vector3.new(0.2, 0, 0))).to.equal(nil)
			expect(step(tracker, S.Running, Vector3.new(0.3, 0, 0))).to.equal("running")
		end)

		it("reset makes the next step send again", function()
			local tracker = ReplicationPuppetLocomotionSystem.new()
			step(tracker, S.Running, Vector3.new(10, 0, 0))
			ReplicationPuppetLocomotionSystem.reset(tracker)
			expect(step(tracker, S.Running, Vector3.new(10, 0, 0))).to.equal("running")
		end)
	end)

	it("gives puppets the 0.7-1.4 stride-rate clamp", function()
		expect(ReplicationPuppetLocomotionSystem.MIN_RATE).to.equal(0.7)
		expect(ReplicationPuppetLocomotionSystem.MAX_RATE).to.equal(1.4)
	end)
end
