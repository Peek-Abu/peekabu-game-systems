local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeePortraitSystem = require(script.Parent.EmployeePortraitSystem)

return function()
	local function part(name, parent, cframe, className)
		local p = Instance.new(className or "Part")
		p.Name = name
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = cframe
		p.Parent = parent
		return p
	end

	local function motor(name, part0, part1, c0, c1)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = part0
		m.Part1 = part1
		m.C0 = c0
		m.C1 = c1
		m.Parent = part1
		return m
	end

	-- A little T-posed rig far from the origin, mid-animation (the arm's Transform is set), with everything a live
	-- character carries that a portrait must not.
	local function makeRig()
		local model = Instance.new("Model")
		model:SetAttribute(EmployeeConstants.NAME_ATTRIBUTE, "Pippa")
		local at = CFrame.new(100, 50, -20) * CFrame.Angles(0, math.rad(90), 0)
		local root = part("HumanoidRootPart", model, at)
		root.Transparency = 1
		local torso = part("UpperTorso", model, at * CFrame.new(0, 1, 0))
		local arm = part("RightUpperArm", model, at * CFrame.new(1, 1, 0))
		motor("Waist", root, torso, CFrame.new(0, 0.5, 0), CFrame.new(0, -0.5, 0))
		local shoulder = motor("RightShoulder", torso, arm, CFrame.new(0.5, 0, 0), CFrame.new(-0.5, 0, 0))
		shoulder.Transform = CFrame.Angles(1, 0, 0)
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
		Instance.new("Animator").Parent = humanoid
		-- A hat on a Weld, a badge on a WeldConstraint.
		local hat = part("Hat", model, at * CFrame.new(0, 3, 0))
		local weld = Instance.new("Weld")
		weld.Part0 = torso
		weld.Part1 = hat
		weld.C0 = CFrame.new(0, 2, 0)
		weld.Parent = hat
		local badge = part("Badge", model, at * CFrame.new(0, 1, -0.6))
		local constraint = Instance.new("WeldConstraint")
		constraint.Part0 = torso
		constraint.Part1 = badge
		constraint.Parent = badge
		-- Things to leave out.
		Instance.new("LocalScript").Parent = model
		local sound = Instance.new("Sound")
		sound.Parent = root
		local tool = Instance.new("Tool")
		part("Handle", tool, at)
		tool.Parent = model
		local pack = Instance.new("Model")
		pack.Name = "VacuumBackpack"
		part("Canister", pack, at)
		pack.Parent = model
		part("Loose", model, at * CFrame.new(0, 0, 5))
		Instance.new("ParticleEmitter").Parent = torso
		-- The face set.
		local plate = part(EmployeeConstants.FACE_PLATE, model, at * CFrame.new(0, 1, -0.5), "MeshPart")
		local plateWeld = Instance.new("WeldConstraint")
		plateWeld.Part0 = torso
		plateWeld.Part1 = plate
		plateWeld.Parent = plate
		local faces = Instance.new("Folder")
		faces.Name = EmployeeConstants.FACES_FOLDER
		faces.Parent = model
		for _, face in { "Happy", "Worried" } do
			local appearance = Instance.new("SurfaceAppearance")
			appearance.Name = face
			appearance.Parent = faces
		end
		model.Archivable = false
		return model
	end

	local function count(model, predicate)
		local n = 0
		for _, d in model:GetDescendants() do
			if predicate(d) then
				n += 1
			end
		end
		return n
	end

	local function near(a, b)
		return (a - b).Magnitude < 1e-3
	end

	describe("build", function()
		it("returns nil for a model with no root part", function()
			expect(EmployeePortraitSystem.build(Instance.new("Model"), nil)).never.to.be.ok()
		end)

		it("copies a non-archivable character and leaves it as it was", function()
			local rig = makeRig()
			local copy = EmployeePortraitSystem.build(rig, nil)
			expect(copy).to.be.ok()
			expect(rig.Archivable).to.equal(false)
			expect(rig:FindFirstChild("Loose")).to.be.ok()
			expect(rig:FindFirstChildWhichIsA("LocalScript")).to.be.ok()
		end)

		it("leaves out scripts, sounds, tools, effects, the animator and the stripped equipment", function()
			local copy = EmployeePortraitSystem.build(makeRig(), nil)
			expect(count(copy, function(d)
				return d:IsA("LuaSourceContainer")
					or d:IsA("Sound")
					or d:IsA("Tool")
					or d:IsA("ParticleEmitter")
					or d:IsA("Animator")
			end)).to.equal(0)
			expect(copy:FindFirstChild("VacuumBackpack")).never.to.be.ok()
		end)

		it("drops parts no joint ties to the root", function()
			local copy = EmployeePortraitSystem.build(makeRig(), nil)
			expect(copy:FindFirstChild("Loose")).never.to.be.ok()
		end)

		it("leaves only anchored, joint-free parts (nothing to simulate or re-render)", function()
			local copy = EmployeePortraitSystem.build(makeRig(), nil)
			expect(count(copy, function(d)
				return d:IsA("JointInstance") or d:IsA("WeldConstraint")
			end)).to.equal(0)
			expect(count(copy, function(d)
				return d:IsA("BasePart") and not d.Anchored
			end)).to.equal(0)
		end)

		it("stands the rig at the origin facing -Z, at rest when there is no pose", function()
			local copy = EmployeePortraitSystem.build(makeRig(), nil)
			expect(near(copy.HumanoidRootPart.Position, Vector3.zero)).to.equal(true)
			expect(near(copy.HumanoidRootPart.CFrame.LookVector, Vector3.new(0, 0, -1))).to.equal(true)
			-- The live animation (the shoulder's Transform) is ignored: the arm is at rest, straight out.
			expect(near(copy.RightUpperArm.Position, Vector3.new(1, 1, 0))).to.equal(true)
			-- Welded pieces follow.
			expect(near(copy.Hat.Position, Vector3.new(0, 3, 0))).to.equal(true)
			expect(near(copy.Badge.Position, Vector3.new(0, 1, -0.6))).to.equal(true)
		end)

		it("applies the pose's joint turns", function()
			local pose = { name = "up", joints = { RightShoulder = Vector3.new(0, 0, 90) } }
			local copy = EmployeePortraitSystem.build(makeRig(), pose)
			expect(near(copy.RightUpperArm.Position, Vector3.new(0.5, 1.5, 0))).to.equal(true)
		end)

		it("puts on the pose's face and drops the unused face set", function()
			local pose = { name = "worried", face = "Worried", joints = {} }
			local copy = EmployeePortraitSystem.build(makeRig(), pose)
			local face = copy[EmployeeConstants.FACE_PLATE]:FindFirstChildWhichIsA("SurfaceAppearance")
			expect(face).to.be.ok()
			expect(face:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal("Worried")
			expect(copy:FindFirstChild(EmployeeConstants.FACES_FOLDER)).never.to.be.ok()
		end)
	end)

	describe("boxes", function()
		it("returns the named parts, or every visible part when none of them is there", function()
			local copy = EmployeePortraitSystem.build(makeRig(), nil)
			expect(#EmployeePortraitSystem.boxes(copy, { "Hat" })).to.equal(1)
			local all = EmployeePortraitSystem.boxes(copy, { "Nothing" })
			-- Every part but the (invisible) root.
			expect(#all).to.equal(5)
		end)
	end)
end
