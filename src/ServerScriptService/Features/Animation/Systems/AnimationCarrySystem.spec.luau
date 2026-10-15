local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local System = require(ServerScriptService.Features.Animation.Systems.AnimationCarrySystem)
local Harness = require(ServerScriptService.Features.Animation.Testing.AnimationCarryRigHarness)
return function()
	local ORIGIN = Vector3.new(0, 3000, 300)
	-- Cargo as CargoSpawnSystem + ArtVisualSystem build it: an invisible 2x2x2 proxy (the size class) with the art
	-- inside it, standing on the proxy's floor, so it is smaller and lower than the proxy.
	local function cargo(at, artSize)
		local size = artSize or Vector3.new(1.8, 1.2, 1.2)
		local proxy = Instance.new("Part")
		proxy.Anchored = true
		proxy.CanCollide = false
		proxy.Size = Vector3.new(2, 2, 2)
		proxy.Transparency = 1
		proxy.CFrame = at
		local art = Instance.new("Model")
		art.Name = "ArtVisual"
		local mesh = Instance.new("Part")
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanQuery = false
		mesh.Size = size
		mesh.CFrame = at * CFrame.new(0, size.Y / 2 - 1, 0)
		mesh.Parent = art
		art.Parent = proxy
		proxy.Parent = Workspace
		return proxy
	end
	local function settle()
		for _ = 1, 4 do
			RunService.Heartbeat:Wait()
		end
	end
	local rig
	beforeEach(function()
		rig = Harness.stockR15(ORIGIN)
	end)
	afterEach(function()
		rig:Destroy()
	end)

	it("bounds a carried item by what can be seen, not its invisible proxy", function()
		local at = CFrame.new(ORIGIN + Vector3.new(5, 0, -3)) * CFrame.Angles(0, math.pi / 2, 0)
		local proxy = cargo(at)
		local box, size = System.visibleBox(proxy)
		expect(size:FuzzyEq(Vector3.new(1.8, 1.2, 1.2), 1e-3)).to.equal(true)
		expect(box.Position:FuzzyEq(Vector3.new(0, -0.4, 0), 1e-3)).to.equal(true)
		proxy.ArtVisual.Part.Transparency = 1
		local _, whole = System.visibleBox(proxy)
		expect(whole:FuzzyEq(Vector3.new(2, 2, 2), 1e-3)).to.equal(true)
		proxy:Destroy()
	end)

	describe("prepare", function()
		it("plans on the visible art's real surface: palms up under its bottom, the item in front", function()
			local proxy = cargo(CFrame.new(ORIGIN + Vector3.new(0, -2, -6)))
			local prepared = System.prepare(rig, proxy, "anything", 1.5)
			expect(prepared).to.be.ok()
			expect(prepared.report.ok).to.equal(true)
			expect(prepared.hold.style).to.equal("under")
			-- The palms are on the art's bottom face (box space: the box is the art's).
			expect(prepared.hold.right.Position.Y).to.be.near(-0.6, 1e-3)
			proxy:Destroy()
		end)

		it("follows the art's CarryHold override", function()
			local proxy = cargo(CFrame.new(ORIGIN + Vector3.new(0, -2, -6)), Vector3.new(1.6, 3.2, 1.6))
			proxy.Size = Vector3.new(2, 3.4, 2)
			proxy.ArtVisual:SetAttribute("CarryHold", "push")
			local prepared = System.prepare(rig, proxy, "anything", 1.5)
			expect(prepared.hold.style).to.equal("push")
			proxy:Destroy()
		end)

		it("hangs a light item from the fist by the art's CarryHandle", function()
			local proxy = cargo(CFrame.new(ORIGIN + Vector3.new(0, -2, -6)), Vector3.new(0.6, 1, 0.4))
			local handle = Instance.new("Attachment")
			handle.Name = "CarryHandle"
			handle.Position = Vector3.new(0, 0.5, 0)
			handle.Parent = proxy.ArtVisual.Part
			local prepared = System.prepare(rig, proxy, "anything", 1.5)
			expect(prepared.hold.style).to.equal("hand")
			expect(prepared.hold.right.Position:FuzzyEq(Vector3.new(0, 0.5, 0), 1e-3)).to.equal(true)
			proxy:Destroy()
		end)
	end)

	describe("mount", function()
		it("joins a held item to the upper torso, the right hand or the root, by its hold", function()
			local proxy = cargo(CFrame.new(ORIGIN + Vector3.new(0, -2, -6)))
			local prepared = System.prepare(rig, proxy, "anything", 1.5)
			proxy:PivotTo(prepared.pivot)
			local box = proxy.CFrame:ToObjectSpace(proxy:GetPivot() * prepared.box)
			local under = System.mount(rig, proxy, prepared.hold, box)
			expect(under.part).to.equal(rig.UpperTorso)
			expect(under.joint).to.equal("weld")
			local hand = table.clone(prepared.hold)
			hand.mount = "rightHand"
			local hanging = System.mount(rig, proxy, hand, box)
			expect(hanging.part).to.equal(rig.RightHand)
			expect(hanging.joint).to.equal("swing")
			local push = table.clone(prepared.hold)
			push.mount = "root"
			local pushed = System.mount(rig, proxy, push, box)
			expect(pushed.part).to.equal(rig.HumanoidRootPart)
			expect(pushed.joint).to.equal("follow")
			expect(pushed.torsoRest).to.be.ok()
			proxy:Destroy()
		end)
	end)

	describe("bind", function()
		it("drives each arm with single-joint controls to the planned pose and lands the palms on the item", function()
			local proxy = cargo(CFrame.new(ORIGIN + Vector3.new(0, -2, -6)))
			local prepared = System.prepare(rig, proxy, "anything", 1.5)
			proxy:PivotTo(prepared.pivot)
			local box = proxy.CFrame:ToObjectSpace(proxy:GetPivot() * prepared.box)
			local mount = System.mount(rig, proxy, prepared.hold, box)
			local weld = Instance.new("Weld")
			weld.Part0 = mount.part
			weld.Part1 = proxy
			weld.C0 = mount.c0
			weld.C1 = mount.c1
			weld.Parent = proxy
			proxy.Anchored = false
			local controller = System.bind(rig, proxy, prepared.hold)
			expect(controller).to.be.ok()
			local controls = 0
			for _, child in rig.Humanoid:GetChildren() do
				if child:IsA("IKControl") then
					controls += 1
					expect(child.SmoothTime).to.equal(0)
					expect(child.ChainRoot.Parent).to.equal(rig)
				end
			end
			expect(controls).to.equal(6)
			-- The avatar joints' limits are lifted while the arms are driven (with them the solver returns NaN).
			expect(rig.RightUpperArm:FindFirstChildOfClass("BallSocketConstraint").Enabled).to.equal(false)
			settle()
			local space = System.liveSpace(rig, prepared.hold)
			local measured = System.measure(rig)
			local pose = System.livePose(rig, "Right", space)
			local palm = pose.hand * measured.right.palmInHand
			local planned = prepared.hold.offset * prepared.hold.right
			expect((palm.Position - planned.Position).Magnitude < 0.01).to.equal(true)
			controller.destroy()
			controller.destroy()
			expect(rig.Humanoid:FindFirstChildOfClass("IKControl")).to.equal(nil)
			expect(rig.RightUpperArm:FindFirstChildOfClass("BallSocketConstraint").Enabled).to.equal(true)
			proxy:Destroy()
		end)

		it("rides a pushed item's targets on the item, re-reaching onto it", function()
			local proxy = cargo(CFrame.new(ORIGIN + Vector3.new(0, -2, -6)), Vector3.new(1.6, 3.2, 1.6))
			proxy.Size = Vector3.new(2, 3.4, 2)
			proxy.ArtVisual:SetAttribute("CarryHold", "push")
			local prepared = System.prepare(rig, proxy, "anything", 10)
			proxy:PivotTo(prepared.pivot)
			local controller = System.bind(rig, proxy, prepared.hold)
			expect(rig.Humanoid:FindFirstChild("CleanupCarryReachRight")).to.be.ok()
			for _, child in rig.Humanoid:GetChildren() do
				if child:IsA("IKControl") then
					expect(child.Target.Parent).to.equal(proxy)
				end
			end
			controller.destroy()
			proxy:Destroy()
		end)

		it("cleans up when the item goes, and refuses a dead carrier", function()
			local proxy = cargo(CFrame.new(ORIGIN + Vector3.new(0, -2, -6)))
			local prepared = System.prepare(rig, proxy, "anything", 1.5)
			System.bind(rig, proxy, prepared.hold)
			proxy:Destroy()
			-- Destroying handlers run deferred.
			settle()
			expect(rig.Humanoid:FindFirstChildOfClass("IKControl")).to.equal(nil)
			rig.Humanoid.Health = 0
			local again = cargo(CFrame.new(ORIGIN + Vector3.new(0, -2, -6)))
			expect(System.bind(rig, again, prepared.hold)).to.equal(nil)
			again:Destroy()
		end)
	end)
end
