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
		-- T-posed with no grip: the fingers point out along +X from the wrist, the palm faces down (its centre on
		-- the hand's -Y face, 0.3 below the middle), the hand 0.4 long along the fingers.
		expect(rig.rightPalmReach).to.be.near(1.2 + math.sqrt(0.2 ^ 2 + 0.3 ^ 2), 1e-3)
		expect(rig.handLength).to.be.near(0.4, 1e-3)
		expect(rig.front).to.be.near(-0.7, 1e-3)
		expect(rig.headFront).to.be.near(-0.8, 1e-3)
		expect(rig.headBottom).to.be.near(1.3, 1e-3)
		expect(rig.floor).to.be.near(-2, 1e-3)
		-- The torso's half width (UpperTorso 1 wide, LowerTorso 1 wide).
		expect(rig.torsoHalfWidth).to.be.near(0.5, 1e-3)
		-- The wrist in the palm's frame: 0.2 back along the fingers (+Z), 0.3 behind the palm's face (-Y).
		expect((rig.rightWristInPalm - Vector3.new(0, -0.3, 0.2)).Magnitude < 1e-3).to.equal(true)
		expect((rig.leftWristInPalm - Vector3.new(0, -0.3, 0.2)).Magnitude < 1e-3).to.equal(true)
		model.Head:Destroy()
		expect(System.measure(model)).to.equal(nil)
		model:Destroy()
	end)
	it("measures the torso and head at the rig's rest pose, not at whatever frame its idle is on", function()
		local model = measuredRig()
		-- The rest pose, as the rig's joints define it: root -> LowerTorso -> UpperTorso -> Head.
		local function motor(name, part0, part1)
			local joint = Instance.new("Motor6D")
			joint.Name = name
			joint.Part0 = part0
			joint.Part1 = part1
			joint.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
			joint.C1 = CFrame.identity
			joint.Parent = part1
		end
		motor("Root", model.HumanoidRootPart, model.LowerTorso)
		motor("Waist", model.LowerTorso, model.UpperTorso)
		motor("Neck", model.UpperTorso, model.Head)
		local rest = System.measure(model)
		-- The idle nods the head forward and leans the torso: the live parts move, the rest pose does not.
		model.Head.CFrame = CFrame.new(0, 1.9, -0.25) * CFrame.Angles(math.rad(-20), 0, 0)
		model.UpperTorso.CFrame = CFrame.new(0, 0.6, -0.2) * CFrame.Angles(math.rad(-8), 0, 0)
		local nodding = System.measure(model)
		expect(nodding.headFront).to.be.near(rest.headFront, 1e-3)
		expect(nodding.headBottom).to.be.near(rest.headBottom, 1e-3)
		expect(nodding.front).to.be.near(rest.front, 1e-3)
		expect(rest.headFront).to.be.near(-0.8, 1e-3)
		expect(rest.headBottom).to.be.near(1.3, 1e-3)
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
	it("finds each palm frame from the rig: palm down at rest in a T pose, fingers along the arm", function()
		local model = measuredRig()
		local right = System.palmOf(model, "Right")
		local left = System.palmOf(model, "Left")
		expect((right.LookVector - Vector3.xAxis).Magnitude < 1e-3).to.equal(true)
		expect((left.LookVector + Vector3.xAxis).Magnitude < 1e-3).to.equal(true)
		expect((right.UpVector + Vector3.yAxis).Magnitude < 1e-3).to.equal(true)
		expect((left.UpVector + Vector3.yAxis).Magnitude < 1e-3).to.equal(true)
		expect((right.Position - Vector3.new(0, -0.3, 0)).Magnitude < 1e-3).to.equal(true)
		model:Destroy()
	end)
	it("plans the hold on the visible art: its near face clear of the head, the palms up under its bottom", function()
		local model = measuredRig()
		local proxy = cargo(CFrame.new(5, 1, -3))
		local prepared = System.prepare(model, proxy, "recyclingBox", nil)
		expect(prepared).to.be.ok()
		local box = prepared.pivot * prepared.box
		-- The root sits at the origin facing -Z. The art (1.6 tall) would reach the head (bottom 1.3) at the belly,
		-- so its near face goes just past the head's front (-0.8), not into it.
		expect(box.Position.Z + 1.4 / 2).to.be.near(-0.8 - 0.05, 1e-3)
		expect(box.Position.Y + 1.6 / 2 > 1.3).to.equal(true)
		expect(prepared.layout.under).to.equal(true)
		for _, contact in { prepared.layout.right, prepared.layout.left } do
			expect(contact.Position.Y).to.be.near(-0.8, 1e-3)
			expect(contact.UpVector.Y > 0.9).to.equal(true)
		end
		-- The hands straddle the art's centre.
		expect(prepared.layout.right.Position.X).to.be.near(-prepared.layout.left.Position.X, 1e-3)
		model:Destroy()
		proxy:Destroy()
	end)
	it("no longer reads authored rim grips: the palms still go under the item", function()
		local model = measuredRig()
		local proxy = cargo(CFrame.new(5, 1, -3))
		for side, x in { Right = 0.5, Left = -0.5 } do
			local grip = Instance.new("Attachment")
			grip.Name = "CarryGrip" .. side
			grip.CFrame = CFrame.new(x, -0.4, 0.7) * CFrame.Angles(math.pi / 2, 0, 0)
			grip.Parent = proxy.ArtVisual.Part
		end
		local prepared = System.prepare(model, proxy, "officePlant", nil)
		expect(prepared).to.be.ok()
		expect(prepared.layout.under).to.equal(true)
		expect(prepared.layout.right.Position.Y).to.be.near(-0.8, 1e-3)
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
		-- The palms go in from the body front, not from the art's near face.
		expect(prepared.layout.right.Position.Z < 0.3).to.equal(true)
		-- The torso front is -0.7; the body gap 0.08.
		expect((prepared.pivot * prepared.box).Position.Z + 0.3).to.be.near(-0.78, 1e-3)
		model:Destroy()
		proxy:Destroy()
	end)
	it("hangs a soft bag from the right hand by its authored CarryHandle", function()
		local model = measuredRig()
		local proxy = cargo(CFrame.new(5, 1, -3))
		local handle = Instance.new("Attachment")
		handle.Name = "CarryHandle"
		handle.Position = Vector3.new(0.1, 0.8, 0)
		handle.Parent = proxy.ArtVisual.Part
		local inPivot = proxy.CFrame:PointToObjectSpace(handle.WorldPosition)
		local prepared = System.prepare(model, proxy, "dustBag", nil)
		expect(prepared).to.be.ok()
		expect(prepared.layout.hang).to.equal(true)
		expect(prepared.layout.mount).to.equal("rightHand")
		expect(prepared.layout.left).to.equal(nil)
		-- Once the bag is moved to its pivot, the handle is where the right palm goes.
		local palm = (prepared.pivot * prepared.box * prepared.layout.right).Position
		expect((prepared.pivot:PointToWorldSpace(inPivot) - palm).Magnitude < 1e-3).to.equal(true)
		model:Destroy()
		proxy:Destroy()
	end)
	describe("mount", function()
		local function placed(joint)
			return joint.part.CFrame * joint.c0 * joint.c1:Inverse()
		end
		it("joins a supported item to the upper torso where it is, so it rides the torso's animation", function()
			local model = measuredRig()
			local root = Instance.new("Part")
			root.CFrame = CFrame.new(0.2, 0.4, -1.2)
			local joint = System.mount(model, root, { offset = CFrame.new(), right = CFrame.new(), mount = "torso" })
			expect(joint.part).to.equal(model.UpperTorso)
			expect(joint.swings).to.equal(false)
			expect(placed(joint).Position:FuzzyEq(root.Position, 1e-4)).to.equal(true)
			model:Destroy()
			root:Destroy()
		end)
		it("joins a cart to the root, and a hanging bag to the right hand at its handle, free to swing", function()
			local model = measuredRig()
			local root = Instance.new("Part")
			root.CFrame = CFrame.new(1.4, -0.3, -0.1)
			local cart = System.mount(model, root, { offset = CFrame.new(), right = CFrame.new(), mount = "root" })
			expect(cart.part).to.equal(model.HumanoidRootPart)
			expect(placed(cart).Position:FuzzyEq(root.Position, 1e-4)).to.equal(true)
			local contact = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, -math.rad(60))
			local hand =
				System.mount(model, root, { offset = CFrame.new(), right = contact, hang = true, mount = "rightHand" })
			expect(hand.part).to.equal(model.RightHand)
			expect(hand.swings).to.equal(true)
			-- Jointed at the handle: the palm's frame on the hand, the handle contact on the bag.
			expect(hand.c0).to.equal(System.palmOf(model, "Right"))
			expect(hand.c1).to.equal(contact)
			-- With the hand's palm on the contact, the bag is where it was planned.
			local handAtContact = root.CFrame * contact * hand.c0:Inverse()
			expect((handAtContact * hand.c0 * hand.c1:Inverse()).Position:FuzzyEq(root.Position, 1e-4)).to.equal(true)
			model:Destroy()
			root:Destroy()
		end)
	end)
	it("drives the right palm to a hanging bag's handle from a target on the upper torso, not the bag", function()
		local model = measuredRig()
		local root = Instance.new("Part")
		root.CFrame = CFrame.new(1.4, -0.4, -0.1)
		local contact = CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, -math.rad(60))
		local controller =
			System.bind(model, root, { offset = CFrame.new(), right = contact, hang = true, mount = "rightHand" })
		expect(controller).to.be.ok()
		local control = model.Humanoid:FindFirstChild("CleanupCarryIKRight")
		expect(model.Humanoid:FindFirstChild("CleanupCarryIKLeft")).to.equal(nil)
		expect(control.EndEffectorOffset).to.equal(System.palmOf(model, "Right"))
		expect(control.Target.Parent).to.equal(model.UpperTorso)
		expect(control.Target.WorldCFrame:FuzzyEq(root.CFrame * contact, 1e-4)).to.equal(true)
		expect(control.Pole.Parent).to.equal(model.UpperTorso)
		expect(#root:GetChildren()).to.equal(0)
		controller.destroy()
		expect(model.UpperTorso:FindFirstChildWhichIsA("Attachment")).to.equal(nil)
		model:Destroy()
		root:Destroy()
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
	it("drives each palm, palm up, under the item and bends the elbows down toward a pole by the sides", function()
		local model = measuredRig()
		local root = Instance.new("Part")
		local layout =
			{ offset = CFrame.new(), right = CFrame.new(0.6, 0, -1), left = CFrame.new(-0.6, 0, -1), under = true }
		local controller = System.bind(model, root, layout)
		expect(controller).to.be.ok()
		local control = model.Humanoid:FindFirstChild("CleanupCarryIKRight")
		expect(control.EndEffectorOffset).to.equal(System.palmOf(model, "Right"))
		expect(control.Pole).to.be.ok()
		expect(control.Pole.Parent).to.equal(root)
		-- Below the shoulder (y 1), behind it and outward.
		local pole = control.Pole.WorldPosition
		expect(pole.Y < 1).to.equal(true)
		expect(pole.Z > 0).to.equal(true)
		expect(pole.X > 0.6).to.equal(true)
		controller.destroy()
		expect(#root:GetChildren()).to.equal(0)
		model:Destroy()
		root:Destroy()
	end)
	it("swings the elbows out to the sides on a round body with the palms close together in front", function()
		local model = measuredRig()
		-- A round torso round the shoulders (x +-0.6): the shoulder joints are inside it, as on Pippa.
		model.UpperTorso.Size = Vector3.new(1.8, 1.6, 1.2)
		model.LowerTorso.Size = Vector3.new(1.8, 0.6, 1.4)
		local root = Instance.new("Part")
		local layout = {
			offset = CFrame.new(),
			right = CFrame.new(0.3, 0.7, -0.7),
			left = CFrame.new(-0.3, 0.7, -0.7),
			under = true,
		}
		local controller = System.bind(model, root, layout)
		expect(controller).to.be.ok()
		for _, side in { "Right", "Left" } do
			local sign = if side == "Right" then 1 else -1
			local pole = model.Humanoid:FindFirstChild("CleanupCarryIK" .. side).Pole.WorldPosition
			-- Out past the torso's side, not down and behind inside it.
			expect(pole.X * sign > 0.9).to.equal(true)
		end
		controller.destroy()
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
