local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local VacuumMotionConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)
local System = require(ServerScriptService.Features.Animation.Systems.AnimationVacuumHoldSystem)
return function()
	-- Two T-posed arms: root at the origin, shoulders at (+-0.5, 1, 0).
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
		for _, side in { { "Right", 1 }, { "Left", -1 } } do
			local name, sx = side[1], side[2]
			block(name .. "UpperArm", Vector3.new(0.7 * sx, 1, 0), Vector3.new(0.4, 0.3, 0.3))
			block(name .. "LowerArm", Vector3.new(1.1 * sx, 1, 0), Vector3.new(0.4, 0.3, 0.3))
			local hand = block(name .. "Hand", Vector3.new(1.45 * sx, 1, 0), Vector3.new(0.3, 0.3, 0.3))
			attach(hand, name .. "GripAttachment", Vector3.new(0.15 * sx, 0, 0))
		end
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
		return model, humanoid
	end

	local hold = {
		grip = CFrame.new(0.6, 0.2, -0.7) * CFrame.Angles(-1, 0, 0),
		rightAt = Vector3.new(0.6, 0.2, -0.7),
		leftAt = Vector3.new(0.6, 0.45, -0.55),
		leftShoulder = Vector3.new(-0.5, 1, 0),
		leftReach = 1.9,
		toolGrip = CFrame.Angles(-1, 0, 0),
		rightPole = Vector3.new(1.5, 0.4, 0.5),
		leftPole = Vector3.new(-1.5, 0.4, 0.5),
		left = CFrame.new(0.6, 0.45, -0.55) * CFrame.Angles(-1.2, 0.3, 0),
		tube = 1,
		height = 1.5,
	}

	local function controls(humanoid)
		local found = {}
		for _, child in humanoid:GetChildren() do
			if child:IsA("IKControl") then
				found[child.ChainRoot.Name] = child
			end
		end
		return found
	end

	it("drives the right grip to the hold's frame and the left hand onto the wand, both fixed to the root", function()
		local model, humanoid = rig()
		local controller = System.hold(model, hold)
		expect(controller).to.be.ok()
		local found = controls(humanoid)
		local right, left = found.RightUpperArm, found.LeftUpperArm
		expect(right.EndEffector.Name).to.equal("RightGripAttachment")
		expect(right.Type).to.equal(Enum.IKControlType.Transform)
		expect(right.Target.Parent.Name).to.equal("HumanoidRootPart")
		expect(right.Target.CFrame).to.equal(hold.grip)
		expect(right.Pole.Position).to.equal(hold.rightPole)
		expect(right.SmoothTime).to.equal(0)
		expect(left.EndEffector.Name).to.equal("LeftGripAttachment")
		expect(left.Type).to.equal(Enum.IKControlType.Transform)
		expect(left.Target.CFrame).to.equal(hold.left)
		-- Each target records its planned frame: clients move their own copies for the motion layers and come back.
		expect(right.Target:GetAttribute(VacuumMotionConstants.REST_ATTRIBUTE)).to.equal(hold.grip)
		expect(left.Target:GetAttribute(VacuumMotionConstants.REST_ATTRIBUTE)).to.equal(hold.left)
		-- And the left paw's point on the wand, its shoulder and its reach (the layers keep it in reach).
		expect(left.Target:GetAttribute(VacuumMotionConstants.AT_ATTRIBUTE)).to.equal(hold.leftAt)
		expect(left.Target:GetAttribute(VacuumMotionConstants.SHOULDER_ATTRIBUTE)).to.equal(hold.leftShoulder)
		expect(left.Target:GetAttribute(VacuumMotionConstants.REACH_ATTRIBUTE)).to.equal(hold.leftReach)
		controller.destroy()
		controller.destroy()
		expect(humanoid:FindFirstChildWhichIsA("IKControl")).to.equal(nil)
		expect(#model.HumanoidRootPart:GetChildren()).to.equal(0)
		model:Destroy()
	end)

	it("holds with the right hand alone when the left cannot reach", function()
		local single = table.clone(hold)
		single.left = nil
		local model, humanoid = rig()
		local controller = System.hold(model, single)
		local found = controls(humanoid)
		expect(found.RightUpperArm).to.be.ok()
		expect(found.LeftUpperArm).to.equal(nil)
		controller.destroy()
		model:Destroy()
	end)

	it("creates nothing without a native right arm", function()
		local model, humanoid = rig()
		model.RightHand.RightGripAttachment:Destroy()
		expect(System.hold(model, hold)).to.equal(nil)
		expect(humanoid:FindFirstChildWhichIsA("IKControl")).to.equal(nil)
		model:Destroy()
	end)
end
