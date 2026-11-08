local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeHeadLookFormulas = require(script.Parent.EmployeeHeadLookFormulas)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)

return function()
	local tuning = EmployeeConstants.HEAD_LOOK

	describe("target", function()
		it("looks straight ahead at the default third-person view", function()
			local yaw, pitch = EmployeeHeadLookFormulas.target(0, tuning.neutral)
			expect(yaw).to.equal(0)
			expect(pitch).to.be.near(0, 1e-9)
		end)

		it("turns toward the look, left positive, within its most", function()
			expect(EmployeeHeadLookFormulas.target(math.rad(20), tuning.neutral)).to.be.near(math.rad(20), 1e-9)
			expect(EmployeeHeadLookFormulas.target(math.rad(-30), tuning.neutral)).to.be.near(math.rad(-30), 1e-9)
			expect(EmployeeHeadLookFormulas.target(math.rad(80), tuning.neutral)).to.be.near(tuning.maxYaw, 1e-9)
			expect(EmployeeHeadLookFormulas.target(math.rad(-80), tuning.neutral)).to.be.near(-tuning.maxYaw, 1e-9)
		end)

		it("eases back to straight ahead for a look behind, never snapping side to side", function()
			expect(EmployeeHeadLookFormulas.target(math.pi, tuning.neutral)).to.be.near(0, 1e-9)
			local last = EmployeeHeadLookFormulas.target(-math.pi, tuning.neutral)
			for degrees = -179, 180 do
				local now = EmployeeHeadLookFormulas.target(math.rad(degrees), tuning.neutral)
				expect(math.abs(now - last) <= math.rad(1.5)).to.equal(true)
				last = now
			end
		end)

		it("tips up and down a share of the look's pitch off the default view, within its most", function()
			local _, up = EmployeeHeadLookFormulas.target(0, tuning.neutral + math.rad(10))
			local _, down = EmployeeHeadLookFormulas.target(0, tuning.neutral - math.rad(10))
			expect(up).to.be.near(math.rad(10) * tuning.pitchShare, 1e-9)
			expect(down).to.be.near(-math.rad(10) * tuning.pitchShare, 1e-9)
			local _, most = EmployeeHeadLookFormulas.target(0, math.rad(89))
			local _, least = EmployeeHeadLookFormulas.target(0, math.rad(-89))
			expect(most).to.be.near(tuning.maxPitch, 1e-9)
			expect(least).to.be.near(-tuning.maxPitch, 1e-9)
		end)
	end)

	describe("ease", function()
		it("moves part of the way toward the target each frame, and gets there", function()
			local x = 0
			local first = EmployeeHeadLookFormulas.ease(0, 1, 1 / 60)
			expect(first > 0 and first < 1).to.equal(true)
			for _ = 1, 120 do
				x = EmployeeHeadLookFormulas.ease(x, 1, 1 / 60)
			end
			expect(x).to.be.near(1, 1e-3)
			expect(EmployeeHeadLookFormulas.ease(0.3, 1, 0)).to.equal(0.3)
		end)
	end)

	describe("transform", function()
		it("is the identity looking straight ahead", function()
			expect(EmployeeHeadLookFormulas.transform(0, 0)).to.equal(CFrame.identity)
		end)

		it("turns the face left for a positive yaw and up for a positive pitch", function()
			local left = EmployeeHeadLookFormulas.transform(math.rad(30), 0).LookVector
			local up = EmployeeHeadLookFormulas.transform(0, math.rad(20)).LookVector
			expect(left.X < -0.4).to.equal(true)
			expect(up.Y > 0.3).to.equal(true)
		end)
	end)

	describe("owned", function()
		local function track(priority, weight, playing)
			return { IsPlaying = playing, Priority = priority, WeightCurrent = weight }
		end

		it("leaves the head to an emote or action playing at Action priority or above", function()
			expect(EmployeeHeadLookFormulas.owned({ track(Enum.AnimationPriority.Action, 1, true) })).to.equal(true)
			expect(EmployeeHeadLookFormulas.owned({ track(Enum.AnimationPriority.Action4, 0.6, true) })).to.equal(true)
		end)

		it("looks around over idles, walks and faded or stopped actions", function()
			expect(EmployeeHeadLookFormulas.owned({
				track(Enum.AnimationPriority.Idle, 1, true),
				track(Enum.AnimationPriority.Movement, 1, true),
				track(Enum.AnimationPriority.Core, 1, true),
				track(Enum.AnimationPriority.Action, 0.02, true),
				track(Enum.AnimationPriority.Action2, 1, false),
			})).to.equal(false)
		end)
	end)
end
