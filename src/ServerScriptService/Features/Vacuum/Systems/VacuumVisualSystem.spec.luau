local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Visual = require(script.Parent.VacuumVisualSystem)
local VacuumAssets = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumAssets)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumSkinRegistry = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumSkinRegistry)
local VisualConstants = require(ServerScriptService.Features.Vacuum.Data.VacuumVisualConstants)

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

	-- Two T-posed arms: floor at y = 0, root at y = 1 (hip 0.5), shoulders 2 up, arm 0.4 + 0.4 + 0.3 to the grip.
	local function makeHolder()
		local model = Instance.new("Model")
		local humanoid = Instance.new("Humanoid")
		humanoid.HipHeight = 0.5
		humanoid.Parent = model
		local root = addPart(model, "HumanoidRootPart", CFrame.new(0, 1, 0), Vector3.new(1, 1, 1))
		model.PrimaryPart = root
		local torso = addPart(model, "UpperTorso", CFrame.new(0, 1.8, 0), Vector3.new(1, 1.2, 0.8))
		for _, side in { { "Right", 1 }, { "Left", -1 } } do
			local name, sx = side[1], side[2]
			attach(torso, name .. "ShoulderRigAttachment", Vector3.new(0.5 * sx, 0.2, 0))
			local upper = addPart(model, name .. "UpperArm", CFrame.new(0.7 * sx, 2, 0))
			attach(upper, name .. "ShoulderRigAttachment", Vector3.new(-0.2 * sx, 0, 0))
			attach(upper, name .. "ElbowRigAttachment", Vector3.new(0.2 * sx, 0, 0))
			local lower = addPart(model, name .. "LowerArm", CFrame.new(1.1 * sx, 2, 0))
			attach(lower, name .. "ElbowRigAttachment", Vector3.new(-0.2 * sx, 0, 0))
			attach(lower, name .. "WristRigAttachment", Vector3.new(0.2 * sx, 0, 0))
			local hand = addPart(model, name .. "Hand", CFrame.new(1.45 * sx, 2, 0))
			attach(hand, name .. "WristRigAttachment", Vector3.new(-0.15 * sx, 0, 0))
			attach(hand, name .. "GripAttachment", Vector3.new(0.15 * sx, 0, 0))
		end
		return model
	end

	local function find(container, name)
		return container:FindFirstChild(name, true)
	end

	describe("measure", function()
		it("reads an arm's shoulder (root space) and lengths from its rig attachments", function()
			local holder = makeHolder()
			local arm = Visual.arm(holder, "Right")
			expect(arm.shoulder.X).to.be.near(0.5, 1e-4)
			expect(arm.shoulder.Y).to.be.near(1, 1e-4)
			expect(arm.upper).to.be.near(0.4, 1e-4)
			expect(arm.lower).to.be.near(0.7, 1e-4)
			holder:Destroy()
		end)

		it("reads the shoulder at the rig's rest pose, not where an animation or a landing has the torso", function()
			-- Studio, a shift's start: the hold was planned while Pippa was being placed in the truck, her torso
			-- 0.43 stud forward of rest, so the left hand's target lay out of her reach and that arm hung at full
			-- stretch, swaying with the idle, 0.21-0.30 stud off the wand.
			local holder = makeHolder()
			local root = holder.HumanoidRootPart
			local torso = holder.UpperTorso
			local waist = Instance.new("Motor6D")
			waist.Name = "Waist"
			waist.Part0 = root
			waist.Part1 = torso
			waist.C0 = CFrame.new(0, 0.8, 0)
			waist.Parent = torso
			torso.CFrame = CFrame.new(0, 1.75, -0.45) * CFrame.Angles(0.3, 0, 0)
			for _, side in { "Right", "Left" } do
				local arm = Visual.arm(holder, side)
				expect(arm.shoulder.X).to.be.near(if side == "Right" then 0.5 else -0.5, 1e-4)
				expect(arm.shoulder.Y).to.be.near(1, 1e-4)
				expect(arm.shoulder.Z).to.be.near(0, 1e-4)
			end
			holder:Destroy()
		end)

		it("has no arm for a rig without the attachments", function()
			local model = Instance.new("Model")
			Instance.new("Humanoid").Parent = model
			expect(Visual.arm(model, "Right")).to.equal(nil)
			model:Destroy()
		end)
	end)

	describe("the wand in the hand", function()
		it("builds the wand round one invisible handle, welded, without collisions, with a hose inlet", function()
			local tool = Instance.new("Tool")
			local handle = Visual.build(tool)
			expect(handle.Name).to.equal("Handle")
			expect(handle.Transparency).to.equal(1)
			expect(find(tool, VacuumConstants.FLOOR_HEAD_NAME)).to.be.ok()
			expect(handle:FindFirstChild("HoseInlet")).to.be.ok()
			local welds = 0
			for _, part in tool:GetDescendants() do
				if part:IsA("BasePart") then
					expect(part.Massless).to.equal(true)
					expect(part.CanCollide or part.CanQuery or part.CanTouch).to.equal(false)
				elseif part:IsA("WeldConstraint") then
					welds += 1
					expect(part.Part0).to.equal(handle)
				end
			end
			expect(welds >= 5).to.equal(true)
			expect(tool.Grip).to.equal(VisualConstants.DEFAULT_GRIP)
			tool:Destroy()
		end)

		it("fits a measured holder: the hold's grip, and a tube that rests the floor head on the floor", function()
			local holder = makeHolder()
			local tool = Instance.new("Tool")
			local handle, hold = Visual.build(tool, holder)
			expect(hold).to.be.ok()
			expect(tool.Grip).to.equal(hold.toolGrip)
			local tube = find(tool, "WandTube")
			expect(tube.Size.Y).to.be.near(hold.tube, 1e-4)
			-- The handle sits square to the root at the grip, hold.height above the floor.
			local head = find(tool, VacuumConstants.FLOOR_HEAD_NAME)
			local bottom = handle.CFrame:PointToObjectSpace(head.Position).Y - head.Size.Y / 2
			local size = VisualConstants.GENERIC_SIZE
			expect(hold.height + bottom).to.be.near(VisualConstants.hold.clearance * size, 1e-3)
			-- The head is out in front of the grip.
			expect(handle.CFrame:PointToObjectSpace(head.Position).Z < 0).to.equal(true)
			tool:Destroy()
			holder:Destroy()
		end)

		it("carries the grip contract: GripUpper on the grip in the right hand, GripLower down the tube", function()
			local holder = makeHolder()
			local tool = Instance.new("Tool")
			local handle, hold = Visual.build(tool, holder)
			local upper = find(tool, "WandGrip"):FindFirstChild("GripUpper")
			local lower = find(tool, "WandTube"):FindFirstChild("GripLower")
			expect(upper:IsA("Attachment")).to.equal(true)
			expect(lower:IsA("Attachment")).to.equal(true)
			-- handle = rightGrip * Tool.Grip:Inverse(), so the right hand's grip is at Tool.Grip in handle space.
			local inHandle = handle.CFrame:PointToObjectSpace(upper.WorldPosition)
			expect((inHandle - hold.toolGrip.Position).Magnitude < 1e-3).to.equal(true)
			-- GripLower stays its modelled distance below the tube's top, however long the tube telescopes, and
			-- lies below and in front of GripUpper.
			local tube = find(tool, "WandTube")
			local size = VisualConstants.GENERIC_SIZE
			local below = (0.5 - VisualConstants.grips.lower.position.Y) * size
			expect(tube.Size.Y / 2 - lower.Position.Y).to.be.near(below, 1e-4)
			local lowerInHandle = handle.CFrame:PointToObjectSpace(lower.WorldPosition)
			expect(lowerInHandle.Y < inHandle.Y - 0.3).to.equal(true)
			expect(lowerInHandle.Z < inHandle.Z).to.equal(true)
			-- Both grips' +Y run up the wand.
			expect(upper.WorldCFrame.UpVector:Dot(lower.WorldCFrame.UpVector)).to.be.near(1, 1e-4)
			tool:Destroy()
			holder:Destroy()
		end)

		it("has a wide floor head, square to the holder", function()
			local tool = Instance.new("Tool")
			local handle = Visual.build(tool)
			local head = find(tool, VacuumConstants.FLOOR_HEAD_NAME)
			-- 1.6x+ the first cut's 0.62 studs as modelled, at the stock size.
			expect(head.Size.X >= 0.62 * 1.6 * VisualConstants.GENERIC_SIZE).to.equal(true)
			expect(head.CFrame.RightVector:Dot(handle.CFrame.RightVector)).to.be.near(1, 1e-4)
			tool:Destroy()
		end)
	end)

	describe("the backpack", function()
		it("is worn on the UpperTorso's back, welded, with a gauge, a lamp, a stowed wand and a hose", function()
			local holder = makeHolder()
			local backpack = Visual.wear(holder)
			expect(backpack).to.be.ok()
			local model = holder:FindFirstChild(VacuumConstants.BACKPACK_NAME)
			expect(model).to.equal(backpack.model)
			local torso = holder.UpperTorso
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					expect(part.Massless).to.equal(true)
					expect(part.CanCollide or part.CanQuery or part.CanTouch).to.equal(false)
					local weld = part:FindFirstChildWhichIsA("Weld")
					expect(weld).to.be.ok()
					expect(weld.Part0).to.equal(torso)
				end
			end
			local body = find(model, "CanisterBody")
			-- Behind the torso (+Z is back).
			expect(torso.CFrame:PointToObjectSpace(body.Position).Z > 0.4).to.equal(true)
			local fill = find(model, VacuumConstants.GAUGE_FILL_NAME)
			expect(fill:GetAttribute("GaugeFullSize")).to.equal(fill.Size)
			-- Empty (hidden) until a client draws its owner's fill: no dust in the depot.
			expect(fill.Transparency).to.equal(1)
			local gaugeWeld = fill:FindFirstChild(VacuumConstants.GAUGE_WELD_NAME)
			expect(gaugeWeld:GetAttribute("GaugeFullC0")).to.equal(gaugeWeld.C0)
			expect(find(model, VacuumConstants.LAMP_NAME)).to.be.ok()
			local hose = find(model, "VacuumHose")
			expect(hose:IsA("Beam")).to.equal(true)
			expect(hose.Attachment0).to.be.ok()
			expect(hose.Attachment1:IsDescendantOf(model.StowedWand)).to.equal(true)
			backpack.destroy()
			expect(holder:FindFirstChild(VacuumConstants.BACKPACK_NAME)).to.equal(nil)
			holder:Destroy()
		end)

		it("unclips the stowed wand and runs the hose to the held one, and back", function()
			local holder = makeHolder()
			local backpack = Visual.wear(holder)
			local model = backpack.model
			local stowed = model.StowedWand
			local tool = Instance.new("Tool")
			local handle = Visual.build(tool, holder)
			local inlet = handle.HoseInlet
			local hose = find(model, "VacuumHose")
			local stowedCurve = hose.CurveSize0
			backpack.setHeld(inlet)
			expect(stowed.Parent).to.equal(nil)
			expect(hose.Attachment1).to.equal(inlet)
			-- Held, the hose loops wide out of the outlet, round the arm.
			expect(hose.CurveSize0 > stowedCurve).to.equal(true)
			backpack.setHeld(nil)
			expect(stowed.Parent).to.equal(model)
			expect(hose.CurveSize0).to.equal(stowedCurve)
			expect(find(model, "VacuumHose").Attachment1:IsDescendantOf(stowed)).to.equal(true)
			backpack.destroy()
			tool:Destroy()
			holder:Destroy()
		end)

		-- The holder with a LowerTorso on a Waist joint and its right hip joint 0.8 above the floor (world).
		local function withHips()
			local holder = makeHolder()
			local lower = addPart(holder, "LowerTorso", CFrame.new(0, 1.1, 0), Vector3.new(1, 0.6, 0.8))
			attach(lower, "RightHipRigAttachment", Vector3.new(0.25, -0.3, 0))
			local waist = Instance.new("Motor6D")
			waist.Name = "Waist"
			waist.Part0 = lower
			waist.Part1 = holder.UpperTorso
			waist.C0 = CFrame.new(0, 0.4, 0)
			waist.C1 = CFrame.new(0, -0.3, 0)
			waist.Parent = holder.UpperTorso
			return holder
		end

		it("stows the held wand telescoped, leaning out and back along the pack, its floor head at the hip", function()
			local holder = withHips()
			local backpack = Visual.wear(holder)
			local stowed = backpack.model.StowedWand
			local tool = Instance.new("Tool")
			local _, hold = Visual.build(tool, holder)
			expect(hold).to.be.ok()
			-- The same wand (every piece as big) with its tube pushed in.
			for _, name in { "WandGrip", "WandInlet", "WandSwivel", "FloorHead", "FloorHeadLip" } do
				local held, onPack = find(tool, name), find(stowed, name)
				expect((held.Size - onPack.Size).Magnitude < 1e-4).to.equal(true)
			end
			local tube = find(stowed, "WandTube")
			expect(tube.Size.Y < hold.tube).to.equal(true)
			-- The floor head's bottom hangs at the hip joint (0.8 up), well clear of the floor (0).
			local head = find(stowed, VacuumConstants.FLOOR_HEAD_NAME)
			expect(head.Position.Y - head.Size.Y / 2).to.be.near(0.8, 1e-3)
			-- From the grip on the pack's right, the wand leans out to the right and back, away from the tail
			-- between the legs; the head lies flat.
			local torso = holder.UpperTorso
			local grip = torso.CFrame:PointToObjectSpace(find(stowed, "WandGrip").Position)
			local low = torso.CFrame:PointToObjectSpace(head.Position)
			expect(grip.X > 0 and grip.Z > 0).to.equal(true)
			expect(low.X > grip.X and low.Z > grip.Z and low.Y < grip.Y).to.equal(true)
			-- Every piece's +Y runs up the wand: the tube leans the stow's lean from the torso's up.
			local lean = math.acos(math.clamp(tube.CFrame.UpVector:Dot(torso.CFrame.UpVector), -1, 1))
			expect(lean).to.be.near(VisualConstants.stow.lean, 1e-3)
			expect(head.CFrame.UpVector:Dot(Vector3.yAxis)).to.be.near(1, 1e-4)
			backpack.destroy()
			tool:Destroy()
			holder:Destroy()
		end)

		it("hangs the stowed floor head at the root's centre when the rig has no hip joint", function()
			local holder = makeHolder()
			local backpack = Visual.wear(holder)
			local head = find(backpack.model.StowedWand, VacuumConstants.FLOOR_HEAD_NAME)
			expect(head.Position.Y - head.Size.Y / 2).to.be.near(holder.HumanoidRootPart.Position.Y, 1e-3)
			backpack.destroy()
			holder:Destroy()
		end)

		it("is not worn by a body without an UpperTorso", function()
			local model = Instance.new("Model")
			expect(Visual.wear(model)).to.equal(nil)
			model:Destroy()
		end)
	end)

	describe("skins", function()
		local function skin(name)
			return VacuumSkinRegistry.get(name)
		end

		it("wears Standard Issue by default: its hose, and the skin recorded on the pack", function()
			local holder = makeHolder()
			local backpack = Visual.wear(holder)
			expect(backpack.skin.name).to.equal(VacuumSkinRegistry.DEFAULT)
			expect(backpack.model:GetAttribute("VacuumSkin")).to.equal(VacuumSkinRegistry.DEFAULT)
			expect(find(backpack.model, "VacuumHose").Texture).to.equal(VacuumAssets.HOSE_TEXTURE)
			backpack.destroy()
			holder:Destroy()
		end)

		it("wears the skin it is given, with that skin's hose", function()
			local holder = makeHolder()
			local backpack = Visual.wear(holder, skin("BrassBellows"))
			expect(backpack.skin.name).to.equal("BrassBellows")
			expect(backpack.model:GetAttribute("VacuumSkin")).to.equal("BrassBellows")
			expect(find(backpack.model, "VacuumHose").Texture).to.equal(VacuumAssets.HOSE_TEXTURE_COPPER)
			backpack.destroy()
			holder:Destroy()
		end)

		it("builds the hand wand in the skin it is given", function()
			local tool = Instance.new("Tool")
			Visual.build(tool, nil, skin("BrassBellows"))
			expect(tool:GetAttribute("VacuumSkin")).to.equal("BrassBellows")
			tool:Destroy()
			local plain = Instance.new("Tool")
			Visual.build(plain)
			expect(plain:GetAttribute("VacuumSkin")).to.equal(VacuumSkinRegistry.DEFAULT)
			plain:Destroy()
		end)
	end)

	describe("fit", function()
		it("uses the employee's registry fit at its scale", function()
			local holder = makeHolder()
			holder:SetAttribute("EmployeeName", "Pippa")
			local fit, scale = Visual.fitOf(holder)
			expect(scale).to.be.near(1.25, 1e-6)
			expect(fit.mount.Position.Y > 0).to.equal(true)
			holder:Destroy()
		end)

		it("fits anyone else from their UpperTorso's size", function()
			local holder = makeHolder()
			local fit, scale = Visual.fitOf(holder)
			expect(scale).to.equal(1)
			expect(fit.mount.Position.Z).to.be.near(0.4, 1e-6)
			expect(fit.size).to.equal(VisualConstants.GENERIC_SIZE)
			holder:Destroy()
		end)
	end)
end
