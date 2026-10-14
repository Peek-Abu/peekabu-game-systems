local Visual = require(script.Parent.VacuumVisualSystem)
return function()
	local function addPart(model, name, cframe, size)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size or Vector3.new(1, 1, 1)
		p.CFrame = cframe
		p.Parent = model
		return p
	end

	local function attach(parent, name, position)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = position
		a.Parent = parent
		return a
	end

	-- A right arm in a T-pose: floor at y = 0, shoulder 2 studs up, arm 0.4 + 0.4 + 0.3 = 1.1 studs to the grip.
	local function makeHolder()
		local model = Instance.new("Model")
		local humanoid = Instance.new("Humanoid")
		humanoid.HipHeight = 0.5
		humanoid.Parent = model
		local root = addPart(model, "HumanoidRootPart", CFrame.new(0, 1, 0), Vector3.new(1, 1, 1))
		model.PrimaryPart = root
		local torso = addPart(model, "UpperTorso", CFrame.new(0, 1.8, 0))
		attach(torso, "RightShoulderRigAttachment", Vector3.new(0.5, 0.2, 0))
		local upper = addPart(model, "RightUpperArm", CFrame.new(0.7, 2, 0))
		attach(upper, "RightShoulderRigAttachment", Vector3.new(-0.2, 0, 0))
		attach(upper, "RightElbowRigAttachment", Vector3.new(0.2, 0, 0))
		local lower = addPart(model, "RightLowerArm", CFrame.new(1.1, 2, 0))
		attach(lower, "RightElbowRigAttachment", Vector3.new(-0.2, 0, 0))
		attach(lower, "RightWristRigAttachment", Vector3.new(0.2, 0, 0))
		local hand = addPart(model, "RightHand", CFrame.new(1.45, 2, 0))
		attach(hand, "RightWristRigAttachment", Vector3.new(-0.15, 0, 0))
		attach(hand, "RightGripAttachment", Vector3.new(0.15, 0, 0))
		return model
	end

	local function lowest(tool)
		local handle = tool.Handle
		local low = math.huge
		for _, p in tool:GetDescendants() do
			if p:IsA("BasePart") and p ~= handle then
				local local_ = handle.CFrame:ToObjectSpace(p.CFrame)
				local half = p.Size / 2
				for _, x in { -1, 1 } do
					for _, y in { -1, 1 } do
						for _, z in { -1, 1 } do
							low = math.min(low, (local_ * Vector3.new(x * half.X, y * half.Y, z * half.Z)).Y)
						end
					end
				end
			end
		end
		return low
	end

	describe("vacuum visual assembly", function()
		it("builds original source around one invisible grip handle without collisions", function()
			local tool = Instance.new("Tool")
			local handle = Visual.build(tool)
			expect(handle.Name).to.equal("Handle")
			expect(handle.Transparency).to.equal(1)
			expect(tool:FindFirstChild("Wide floor head", true) ~= nil).to.equal(true)
			for _, part in tool:GetDescendants() do
				if part:IsA("BasePart") then
					expect(part.Massless).to.equal(true)
					expect(part.CanCollide or part.CanQuery or part.CanTouch).to.equal(false)
				end
			end
			tool:Destroy()
		end)
		it("welds every visible part to the single grip root", function()
			local tool = Instance.new("Tool")
			local handle = Visual.build(tool)
			local count = 0
			for _, weld in tool:GetDescendants() do
				if weld:IsA("WeldConstraint") then
					count += 1
					expect(weld.Part0).to.equal(handle)
				end
			end
			expect(count >= 38).to.equal(true)
			tool:Destroy()
		end)
	end)

	describe("fitting the holder", function()
		it("measures how high a hanging arm holds the grip above the floor", function()
			local holder = makeHolder()
			-- Shoulder at 2, arm 1.1 long: the grip hangs 0.9 above the floor.
			expect(Visual.hangHeight(holder)).to.be.near(0.9, 1e-3)
			holder:Destroy()
		end)
		it("has no hang height for a rig without the arm attachments", function()
			local model = Instance.new("Model")
			Instance.new("Humanoid").Parent = model
			expect(Visual.hangHeight(model)).to.equal(nil)
			model:Destroy()
		end)
		it(
			"keeps full size when the grip hangs high enough, shrinks to fit otherwise, never below the floor",
			function()
				expect(Visual.holdScale(nil, 1.9)).to.equal(1)
				expect(Visual.holdScale(2.11, 1.9)).to.equal(1)
				local scale = Visual.holdScale(0.95, 1.9)
				expect(scale < 1).to.equal(true)
				expect(scale * 1.9 <= 0.95).to.equal(true)
				expect(Visual.holdScale(0.01, 1.9) > 0).to.equal(true)
			end
		)
		it("builds a vacuum whose lowest point clears the floor under a short holder's hanging hand", function()
			local holder = makeHolder()
			local full = Instance.new("Tool")
			Visual.build(full)
			local fitted = Instance.new("Tool")
			Visual.build(fitted, holder)
			expect(lowest(full) < -0.9).to.equal(true)
			expect(lowest(fitted) >= -0.9).to.equal(true)
			expect(fitted:GetAttribute("VacuumHoldScale") < 1).to.equal(true)
			expect(full:GetAttribute("VacuumHoldScale")).to.equal(1)
			full:Destroy()
			fitted:Destroy()
			holder:Destroy()
		end)
	end)
end
