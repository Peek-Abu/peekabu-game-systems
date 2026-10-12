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
