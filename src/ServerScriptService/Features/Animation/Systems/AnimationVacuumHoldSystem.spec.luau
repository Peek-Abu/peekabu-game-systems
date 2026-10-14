local ServerScriptService = game:GetService("ServerScriptService")
local System = require(ServerScriptService.Features.Animation.Systems.AnimationVacuumHoldSystem)
return function()
	-- A T-posed right arm: root at the origin, shoulder at (0.5, 1, 0), 0.4 + 0.4 + 0.3 to the grip.
	local function rig()
		local model = Instance.new("Model")
		local function block(name, position, size)
			local part = Instance.new("Part")
			part.Name = name
			part.Anchored = true
			part.Size = size
			part.CFrame = CFrame.new(position)
			part.Parent = model
			return part
		end
		local function attach(parent, name, position)
			local attachment = Instance.new("Attachment")
			attachment.Name = name
			attachment.Position = position
			attachment.Parent = parent
			return attachment
		end
		block("HumanoidRootPart", Vector3.zero, Vector3.new(2, 2, 1))
		block("UpperTorso", Vector3.new(0, 0.5, 0), Vector3.new(1.2, 1.4, 1))
		local upper = block("RightUpperArm", Vector3.new(0.7, 1, 0), Vector3.new(0.4, 0.3, 0.3))
		attach(upper, "RightShoulderRigAttachment", Vector3.new(-0.2, 0, 0))
		attach(upper, "RightElbowRigAttachment", Vector3.new(0.2, 0, 0))
		local lower = block("RightLowerArm", Vector3.new(1.1, 1, 0), Vector3.new(0.4, 0.3, 0.3))
		attach(lower, "RightElbowRigAttachment", Vector3.new(-0.2, 0, 0))
		attach(lower, "RightWristRigAttachment", Vector3.new(0.2, 0, 0))
		local hand = block("RightHand", Vector3.new(1.45, 1, 0), Vector3.new(0.3, 0.3, 0.3))
		attach(hand, "RightWristRigAttachment", Vector3.new(-0.15, 0, 0))
		attach(hand, "RightGripAttachment", Vector3.new(0.15, 0, 0))
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
		return model, humanoid
	end
	local grip = CFrame.Angles(-math.pi / 2, 0, 0)

	it("drives only the right arm's grip to a lifted target fixed to the root", function()
		local model, humanoid = rig()
		local controller = System.hold(model, grip, 0.5, 0.6)
		expect(controller).to.be.ok()
		local control = humanoid:FindFirstChildWhichIsA("IKControl")
		expect(control.ChainRoot.Name).to.equal("RightUpperArm")
		expect(control.EndEffector.Name).to.equal("RightGripAttachment")
		local target = control.Target
		expect(target.Parent.Name).to.equal("HumanoidRootPart")
		-- Hanging, the grip is 1.1 below the shoulder; lifted 0.5, it is 0.6 below.
		expect(target.Position.Y).to.be.near(1 - 1.1 + 0.5, 1e-3)
		-- Beside the torso (0.6 half-wide) by the vacuum's half-width, as far as the arm reaches.
		expect(target.Position.X > 0.5).to.equal(true)
		-- Oriented so the handle (target * grip⁻¹) stands upright.
		local handle = target.CFrame * grip:Inverse()
		expect(handle.UpVector:Dot(Vector3.yAxis)).to.be.near(1, 1e-3)
		controller.destroy()
		controller.destroy()
		expect(humanoid:FindFirstChildWhichIsA("IKControl")).to.equal(nil)
		expect(model.HumanoidRootPart:FindFirstChild("VacuumHoldTarget")).to.equal(nil)
		model:Destroy()
	end)

	it("creates nothing when there is nothing to lift, or no native right arm", function()
		local model, humanoid = rig()
		expect(System.hold(model, grip, 0, 0.6)).to.equal(nil)
		model.RightHand.RightGripAttachment:Destroy()
		expect(System.hold(model, grip, 0.5, 0.6)).to.equal(nil)
		expect(humanoid:FindFirstChildWhichIsA("IKControl")).to.equal(nil)
		model:Destroy()
	end)
end
