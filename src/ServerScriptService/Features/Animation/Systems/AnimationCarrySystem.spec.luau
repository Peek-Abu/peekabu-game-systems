local ServerScriptService = game:GetService("ServerScriptService")
local System = require(ServerScriptService.Features.Animation.Systems.AnimationCarrySystem)
return function()
	local function fixture()
		local model = Instance.new("Model")
		for _, name in
			{
				"HumanoidRootPart",
				"LeftUpperArm",
				"LeftLowerArm",
				"LeftHand",
				"RightUpperArm",
				"RightLowerArm",
				"RightHand",
			}
		do
			local part = Instance.new("Part")
			part.Name = name
			part.Parent = model
		end
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
		return model, humanoid
	end
	-- A T-posed rig with real rig attachments: root at the origin (2 tall), HipHeight 1, so the floor is at -2.
	local function measuredRig()
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
		end
		block("HumanoidRootPart", Vector3.zero, Vector3.new(2, 2, 1))
		block("UpperTorso", Vector3.new(0, 0.6, -0.1), Vector3.new(1, 1.6, 1.2))
		block("LowerTorso", Vector3.new(0, -0.6, 0), Vector3.new(1, 0.6, 1))
		block("Head", Vector3.new(0, 2, 0), Vector3.new(1.6, 1.4, 1.6))
		for _, side in { "Left", "Right" } do
			local s = if side == "Right" then 1 else -1
			local upper = block(side .. "UpperArm", Vector3.new(s * 0.9, 1, 0), Vector3.new(0.6, 0.4, 0.4))
			attach(upper, side .. "ShoulderRigAttachment", Vector3.new(-s * 0.3, 0, 0))
			attach(upper, side .. "ElbowRigAttachment", Vector3.new(s * 0.3, 0, 0))
			local lower = block(side .. "LowerArm", Vector3.new(s * 1.5, 1, 0), Vector3.new(0.6, 0.4, 0.4))
			attach(lower, side .. "ElbowRigAttachment", Vector3.new(-s * 0.3, 0, 0))
			attach(lower, side .. "WristRigAttachment", Vector3.new(s * 0.3, 0, 0))
			local hand = block(side .. "Hand", Vector3.new(s * 2, 1, 0), Vector3.new(0.4, 0.6, 0.4))
			attach(hand, side .. "WristRigAttachment", Vector3.new(-s * 0.2, 0, 0))
		end
		local humanoid = Instance.new("Humanoid")
		humanoid.HipHeight = 1
		humanoid.Parent = model
		return model
	end
	it("measures the carrier from its rig: shoulders, reach to the palm, torso and head fronts, floor", function()
		local model = measuredRig()
		local rig = System.measure(model)
		expect(rig).to.be.ok()
		expect((rig.rightShoulder - Vector3.new(0.6, 1, 0)).Magnitude < 1e-3).to.equal(true)
		expect((rig.leftShoulder - Vector3.new(-0.6, 1, 0)).Magnitude < 1e-3).to.equal(true)
		-- 0.6 + 0.6 of arm, then wrist (-0.2, 0, 0) to the palm (0, -0.3, 0) in the hand.
		expect(rig.rightReach).to.be.near(1.2 + math.sqrt(0.2 ^ 2 + 0.3 ^ 2), 1e-3)
		expect(rig.front).to.be.near(-0.7, 1e-3)
		expect(rig.headFront).to.be.near(-0.8, 1e-3)
		expect(rig.headBottom).to.be.near(1.3, 1e-3)
		expect(rig.floor).to.be.near(-2, 1e-3)
		model.Head:Destroy()
		expect(System.measure(model)).to.equal(nil)
		model:Destroy()
	end)
	it("binds only arm chains to real cargo attachments and destroys owned controls idempotently", function()
		local model, humanoid = fixture()
		local root = Instance.new("Part")
		local layout = { offset = CFrame.new(), right = CFrame.new(1, 0.5, 1), left = CFrame.new(-1, 0.5, 1) }
		local controller = System.bind(model, root, layout)
		expect(controller).to.be.ok()
		local count = 0
		for _, child in humanoid:GetChildren() do
			if child:IsA("IKControl") then
				count += 1
				expect(child.ChainRoot.Name:find("UpperArm") ~= nil).to.equal(true)
				expect(child.EndEffector.Name:find("Hand") ~= nil).to.equal(true)
				expect(child.Target.Parent).to.equal(root)
			end
		end
		expect(count).to.equal(2)
		controller.destroy()
		controller.destroy()
		expect(#root:GetChildren()).to.equal(0)
		expect(humanoid:FindFirstChildWhichIsA("IKControl")).to.equal(nil)
		model:Destroy()
		root:Destroy()
	end)
	it("creates one arm for a one-hand layout and cleans up when cargo is destroyed", function()
		local model, humanoid = fixture()
		local root = Instance.new("Part")
		local controller = System.bind(model, root, { offset = CFrame.new(), right = CFrame.new(0, 1, 0), left = nil })
		expect(#root:GetChildren()).to.equal(1)
		root:Destroy()
		task.wait(0.1) -- Destroying is deferred: the controller cleans up on the signal
		expect(humanoid:FindFirstChildWhichIsA("IKControl")).to.equal(nil)
		controller.destroy()
		model:Destroy()
	end)
	it("refuses a missing native arm instead of inventing a torso chain", function()
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		expect(System.bind(model, root, { offset = CFrame.new(), right = CFrame.new(), left = nil })).to.equal(nil)
		expect(#root:GetChildren()).to.equal(0)
		model:Destroy()
		root:Destroy()
	end)
	it("refuses an already dead humanoid and cleans up when its humanoid is removed", function()
		local model, humanoid = fixture()
		local root = Instance.new("Part")
		humanoid.Health = 0
		expect(System.bind(model, root, { offset = CFrame.new(), right = CFrame.new(), left = nil })).to.equal(nil)
		humanoid.Health = 100
		local controller = System.bind(model, root, { offset = CFrame.new(), right = CFrame.new(), left = nil })
		humanoid:Destroy()
		task.wait(0.1) -- Destroying is deferred: the controller cleans up on the signal
		expect(#root:GetChildren()).to.equal(0)
		controller.destroy()
		model:Destroy()
		root:Destroy()
	end)
end
