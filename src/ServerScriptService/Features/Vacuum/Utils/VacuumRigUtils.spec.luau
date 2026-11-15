local ServerScriptService = game:GetService("ServerScriptService")

local Rig = require(script.Parent.VacuumRigUtils)
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

	describe("arms", function()
		it("reads an arm's shoulder (root space) and lengths from its rig attachments", function()
			local holder = makeHolder()
			local arm = Rig.arm(holder, "Right")
			expect(arm.shoulder.X).to.be.near(0.5, 1e-4)
			expect(arm.shoulder.Y).to.be.near(1, 1e-4)
			expect(arm.upper).to.be.near(0.4, 1e-4)
			-- The forearm, then the hand from its wrist to its wrap point (WRAP of the way to the grip attachment).
			expect(arm.lower).to.be.near(0.4 + 0.3 * VisualConstants.WRAP, 1e-4)
			holder:Destroy()
		end)

		it(
			"holds the wand inside the paw: the wrap point lies between wrist and grip, given in the grip's space",
			function()
				local holder = makeHolder()
				for _, side in { { "Right", 1 }, { "Left", -1 } } do
					local name, sx = side[1], side[2]
					local wrap = Rig.wrapOf(holder, name)
					expect(wrap.X).to.be.near(sx * (-0.15 + 0.3 * VisualConstants.WRAP), 1e-4)
					local arm = Rig.arm(holder, name)
					-- From the grip attachment (at the paw's tip) back toward the wrist.
					expect(arm.wrap.Magnitude).to.be.near(0.3 * (1 - VisualConstants.WRAP), 1e-4)
					local grip = holder[name .. "Hand"][name .. "GripAttachment"]
					expect((grip.CFrame:PointToWorldSpace(arm.wrap) - wrap).Magnitude < 1e-4).to.equal(true)
				end
				holder:Destroy()
			end
		)

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
				local arm = Rig.arm(holder, side)
				expect(arm.shoulder.X).to.be.near(if side == "Right" then 0.5 else -0.5, 1e-4)
				expect(arm.shoulder.Y).to.be.near(1, 1e-4)
				expect(arm.shoulder.Z).to.be.near(0, 1e-4)
			end
			holder:Destroy()
		end)

		it("has no arm and no wrap point for a rig without the attachments", function()
			local model = Instance.new("Model")
			Instance.new("Humanoid").Parent = model
			expect(Rig.arm(model, "Right")).to.equal(nil)
			expect(Rig.wrapOf(model, "Right")).to.equal(nil)
			model:Destroy()
		end)
	end)

	describe("hip", function()
		it("reads the right hip in the torso's space at the rest pose, through the waist joint", function()
			local holder = makeHolder()
			local lower = Instance.new("Part")
			lower.Name = "LowerTorso"
			lower.Anchored = true
			lower.CFrame = CFrame.new(0, 1, 0)
			lower.Parent = holder
			attach(lower, "RightHipRigAttachment", Vector3.new(0.3, -0.2, 0))
			local torso = holder.UpperTorso
			local waist = Instance.new("Motor6D")
			waist.Part0 = lower
			waist.Part1 = torso
			waist.C0 = CFrame.new(0, 0.5, 0)
			waist.C1 = CFrame.new(0, -0.3, 0)
			waist.Parent = torso
			-- Posed anywhere: the answer is the rest pose's (torso = lower * C0 * C1:Inverse(), so 0.8 above the lower).
			torso.CFrame = CFrame.new(0, 3, 2) * CFrame.Angles(0.5, 0, 0)
			local hip = Rig.hipInTorso(holder, torso)
			expect((hip - Vector3.new(0.3, -1, 0)).Magnitude < 1e-4).to.equal(true)
			holder:Destroy()
		end)

		it("falls back to the root's centre, live, on a rig without a hip joint", function()
			local holder = makeHolder()
			local torso = holder.UpperTorso
			local hip = Rig.hipInTorso(holder, torso)
			expect((hip - Vector3.new(0, -0.8, 0)).Magnitude < 1e-4).to.equal(true)
			holder:Destroy()
		end)

		it("falls back to the torso's bottom with no root either", function()
			local model = Instance.new("Model")
			local torso = addPart(model, "UpperTorso", CFrame.new(0, 2, 0), Vector3.new(1, 1.2, 0.8))
			expect((Rig.hipInTorso(model, torso) - Vector3.new(0, -0.6, 0)).Magnitude < 1e-4).to.equal(true)
			model:Destroy()
		end)
	end)

	describe("fit", function()
		it("uses the employee's registry fit at its scale", function()
			local holder = makeHolder()
			holder:SetAttribute("EmployeeName", "Pippa")
			local fit, scale = Rig.fitOf(holder)
			expect(scale).to.be.near(1.25, 1e-6)
			expect(fit.mount.Position.Y > 0).to.equal(true)
			holder:Destroy()
		end)

		it("fits anyone else from their UpperTorso's size", function()
			local holder = makeHolder()
			local fit, scale = Rig.fitOf(holder)
			expect(scale).to.equal(1)
			expect(fit.mount.Position.Z).to.be.near(0.4, 1e-6)
			expect(fit.size).to.equal(VisualConstants.GENERIC_SIZE)
			holder:Destroy()
		end)

		it("fits no character at all at the generic size", function()
			local fit, scale = Rig.fitOf(nil)
			expect(scale).to.equal(1)
			expect(fit.size).to.equal(VisualConstants.GENERIC_SIZE)
		end)
	end)
end
