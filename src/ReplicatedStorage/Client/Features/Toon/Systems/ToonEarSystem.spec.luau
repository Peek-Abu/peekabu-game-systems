local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToonConstants = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonConstants)
local ToonEarSystem = require(script.Parent.ToonEarSystem)

return function()
	local function makeToon(position)
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.CFrame = CFrame.new(position)
		root.Parent = model
		model.PrimaryPart = root
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Parent = model
		local motors = {}
		for _, joint in ToonConstants.EAR_JOINTS do
			local ear = Instance.new("Part")
			ear.Name = joint.name .. "Part"
			ear.Parent = model
			local motor = Instance.new("Motor6D")
			motor.Name = joint.name
			motor.Part0 = head
			motor.Part1 = ear
			motor.Parent = ear
			motors[joint.side] = motor
		end
		return model, root, motors
	end

	local function isIdentity(cframe)
		return cframe.Position.Magnitude < 1e-6 and cframe.LookVector:Dot(Vector3.new(0, 0, -1)) > 0.999999
	end

	describe("step", function()
		it("drives both ear joints of a nearby toon", function()
			local ears = ToonEarSystem.new()
			local model, root, motors = makeToon(Vector3.new(0, 0, 0))
			local untrack = ears.track(model)
			ears.step(1 / 60, Vector3.new(0, 0, 10), 0)
			root.CFrame = CFrame.new(0, 0, -0.3)
			for i = 1, 10 do
				ears.step(1 / 60, Vector3.new(0, 0, 10), i / 60)
			end
			expect(isIdentity(motors[-1].Transform)).to.equal(false)
			expect(isIdentity(motors[1].Transform)).to.equal(false)
			expect(ears.getState().active).to.equal(1)
			untrack()
			model:Destroy()
		end)

		it("leaves far toons at rest", function()
			local ears = ToonEarSystem.new()
			local model, _, motors = makeToon(Vector3.new(0, 0, 0))
			local untrack = ears.track(model)
			local far = Vector3.new(ToonConstants.EAR_RADIUS + 50, 0, 0)
			for i = 1, 10 do
				ears.step(1 / 60, far, i / 60)
			end
			expect(isIdentity(motors[-1].Transform)).to.equal(true)
			expect(ears.getState().active).to.equal(0)
			untrack()
			model:Destroy()
		end)

		it("puts the ears back to rest and forgets the toon when untracked", function()
			local ears = ToonEarSystem.new()
			local model, root, motors = makeToon(Vector3.new(0, 0, 0))
			local untrack = ears.track(model)
			ears.step(1 / 60, Vector3.new(0, 0, 10), 0)
			root.CFrame = CFrame.new(3, 0, 0)
			ears.step(1 / 60, Vector3.new(0, 0, 10), 1 / 60)
			untrack()
			expect(isIdentity(motors[1].Transform)).to.equal(true)
			expect(ears.getState().tracked).to.equal(0)
			model:Destroy()
		end)

		it("tracks a model without ear joints harmlessly", function()
			local ears = ToonEarSystem.new()
			local model = Instance.new("Model")
			local untrack = ears.track(model)
			ears.step(1 / 60, Vector3.new(), 0)
			expect(ears.getState().active).to.equal(0)
			untrack()
			expect(ears.getState().tracked).to.equal(0)
			model:Destroy()
		end)

		it("picks up ear joints that arrive after tracking (replication order)", function()
			local ears = ToonEarSystem.new()
			local model, root, motors = makeToon(Vector3.new(0, 0, 0))
			local parents = {}
			for side, motor in motors do
				parents[side] = motor.Parent
				motor.Parent = nil
			end
			local untrack = ears.track(model)
			ears.step(1 / 60, Vector3.new(0, 0, 10), 0)
			expect(ears.getState().active).to.equal(0)
			for side, motor in motors do
				motor.Parent = parents[side]
			end
			ears.step(1 / 60, Vector3.new(0, 0, 10), 0)
			root.CFrame = CFrame.new(0, 0, -0.3)
			ears.step(1 / 60, Vector3.new(0, 0, 10), 1 / 60)
			expect(ears.getState().active).to.equal(1)
			expect(isIdentity(motors[1].Transform)).to.equal(false)
			untrack()
			model:Destroy()
		end)
	end)
end
