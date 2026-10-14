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
	-- Cargo as CargoSpawnSystem + ArtVisualSystem build it: an invisible 2x2x2 proxy (the size class) with the
	-- art welded inside, uniformly fitted and standing on the proxy's floor, so it is smaller and lower.
	local function cargo(at)
		local proxy = Instance.new("Part")
		proxy.Anchored = true
		proxy.Size = Vector3.new(2, 2, 2)
		proxy.Transparency = 1
		proxy.CFrame = at
		local art = Instance.new("Model")
		art.Name = "ArtVisual"
		local mesh = Instance.new("Part")
		mesh.Anchored = true
		mesh.Size = Vector3.new(2, 1.6, 1.4)
		mesh.CFrame = at * CFrame.new(0, -0.2, 0)
		mesh.Parent = art
		art.Parent = proxy
		return proxy
	end
	it("bounds a carried item by what can be seen, not its invisible proxy", function()
		local at = CFrame.new(5, 1, -3) * CFrame.Angles(0, math.pi / 2, 0)
		local proxy = cargo(at)
		local box, size = System.visibleBox(proxy)
		expect((size - Vector3.new(2, 1.6, 1.4)).Magnitude < 1e-3).to.equal(true)
		-- Relative to the item's pivot, so it follows the item wherever it is moved.
		expect((box.Position - Vector3.new(0, -0.2, 0)).Magnitude < 1e-3).to.equal(true)
		-- Nothing visible (a hidden item, or art that never attached): the whole item.
		proxy.ArtVisual.Part.Transparency = 1
		local _, whole = System.visibleBox(proxy)
		expect((whole - Vector3.new(2, 2, 2)).Magnitude < 1e-3).to.equal(true)
		proxy:Destroy()
	end)
	it("plans the hold on the visible art: its near face at the belly, the hands on its surface", function()
		local model = measuredRig()
		local proxy = cargo(CFrame.new(5, 1, -3))
		local prepared = System.prepare(model, proxy, "recyclingBox", nil)
		expect(prepared).to.be.ok()
		local box = prepared.pivot * prepared.box
		-- The root sits at the origin facing -Z: the art's near face is just in front of the torso (-0.7).
		expect(box.Position.Z + 1.4 / 2).to.be.near(-0.7 - 0.08, 1e-3)
		for _, contact in { prepared.layout.right, prepared.layout.left } do
			local p = contact.Position
			local onSurface = math.abs(math.abs(p.X) - 1) < 1e-3
				or math.abs(math.abs(p.Y) - 0.8) < 1e-3
				or math.abs(math.abs(p.Z) - 0.7) < 1e-3
			expect(onSurface).to.equal(true)
		end
		-- The hands straddle the art's centre.
		expect(prepared.layout.right.Position.X).to.be.near(-prepared.layout.left.Position.X, 1e-3)
		model:Destroy()
		proxy:Destroy()
	end)
	it("puts the hands on authored grips and holds the item at their height", function()
		local model = measuredRig()
		local proxy = cargo(CFrame.new(5, 1, -3))
		-- Low on the art's near face, like a pot's rim under a plant.
		for side, x in { Right = 0.5, Left = -0.5 } do
			local grip = Instance.new("Attachment")
			grip.Name = "CarryGrip" .. side
			grip.CFrame = CFrame.new(x, -0.4, 0.7) * CFrame.Angles(math.pi / 2, 0, 0)
			grip.Parent = proxy.ArtVisual.Part
		end
		local prepared = System.prepare(model, proxy, "officePlant", nil)
		expect(prepared).to.be.ok()
		expect((prepared.layout.right.Position - Vector3.new(0.5, -0.4, 0.7)).Magnitude < 1e-3).to.equal(true)
		expect((prepared.layout.left.Position - Vector3.new(-0.5, -0.4, 0.7)).Magnitude < 1e-3).to.equal(true)
		-- The grips are at hand height: half an arm (1.2 + the wrist-to-palm 0.36) below the shoulders (1).
		local reach = 1.2 + math.sqrt(0.2 ^ 2 + 0.3 ^ 2)
		local grip = (prepared.pivot * prepared.box * prepared.layout.right).Position
		expect(grip.Y).to.be.near(1 - reach * 0.5, 1e-3)
		-- Out of reach: the box contacts instead, not no hands at all.
		proxy.ArtVisual.Part.CarryGripRight.Position = Vector3.new(0.5, -0.4, -40)
		local fallback = System.prepare(model, proxy, "officePlant", nil)
		expect(fallback).to.be.ok()
		expect(fallback.layout.right.Position.Z > -1).to.equal(true)
		model:Destroy()
		proxy:Destroy()
	end)
	it("rests an authored body front against the torso instead of the art's near face", function()
		local model = measuredRig()
		local proxy = cargo(CFrame.new(5, 1, -3))
		local front = Instance.new("Attachment")
		front.Name = "CarryBodyFront"
		front.Position = Vector3.new(0, -0.4, 0.3)
		front.Parent = proxy.ArtVisual.Part
		local prepared = System.prepare(model, proxy, "recyclingBox", nil)
		expect(prepared).to.be.ok()
		-- The torso front is -0.7; the body gap 0.08.
		expect((prepared.pivot * prepared.box).Position.Z + 0.3).to.be.near(-0.78, 1e-3)
		model:Destroy()
		proxy:Destroy()
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
