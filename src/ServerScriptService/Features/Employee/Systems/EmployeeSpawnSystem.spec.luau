local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeSpawnSystem = require(script.Parent.EmployeeSpawnSystem)

return function()
	local function part(model, name, size)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size or Vector3.new(1, 1, 1)
		p.Parent = model
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

	-- A cut-down Pippa: root, torso, right arm chain, head and one ear.
	local function makeTemplate()
		local model = Instance.new("Model")
		model.Name = "Pippa"
		model:SetAttribute(EmployeeConstants.NAME_ATTRIBUTE, "Pippa")
		Instance.new("Humanoid").Parent = model
		local root = part(model, "HumanoidRootPart")
		local lower = part(model, "LowerTorso")
		local upper = part(model, "UpperTorso")
		local arm = part(model, "RightUpperArm")
		local fore = part(model, "RightLowerArm")
		local hand = part(model, "RightHand", Vector3.new(0.54, 0.43, 0.78))
		local leftHand = part(model, "LeftHand", Vector3.new(0.54, 0.43, 0.78))
		local head = part(model, "Head")
		local ear = part(model, "LeftEar")
		model.PrimaryPart = root
		motor("Root", root, lower, CFrame.new(), CFrame.new(0, 0, -0.17))
		motor("Waist", lower, upper, CFrame.new(0, 0.2, -0.17), CFrame.new(0, -0.46, 0.08))
		motor("RightShoulder", upper, arm, CFrame.new(0.36, 0.26, 0.08), CFrame.new(-0.21, 0, 0))
		motor("RightElbow", arm, fore, CFrame.new(0.21, 0, 0), CFrame.new(-0.19, 0, 0))
		motor("RightWrist", fore, hand, CFrame.new(0.19, 0, 0), CFrame.new(-0.23, 0, 0.087))
		motor("LeftWrist", upper, leftHand, CFrame.new(-0.5, 0, 0), CFrame.new(0.23, 0, 0.087))
		motor("Neck", upper, head, CFrame.new(0, 0.61, 0.08), CFrame.new(0, -0.69, 0))
		motor("LeftEarBase", head, ear, CFrame.new(-0.36, 0.48, 0.05), CFrame.new(0.48, -0.5, 0.01))
		return model
	end

	local function makeSource(template)
		local source = Instance.new("Folder")
		local assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = source
		local crew = Instance.new("Folder")
		crew.Name = "CleanupCrew"
		crew.Parent = assets
		local characters = Instance.new("Folder")
		characters.Name = "Characters"
		characters.Parent = crew
		if template ~= nil then
			template.Parent = characters
		end
		return source
	end

	describe("prepare", function()
		it("adds the R15 rig attachments at every joint pivot, the grips and an Animator", function()
			local model = makeTemplate()
			local added = EmployeeSpawnSystem.prepare(model)
			expect(added > 0).to.equal(true)
			local shoulder = model.UpperTorso:FindFirstChild("RightShoulderRigAttachment")
			expect(shoulder).to.be.ok()
			expect((shoulder.Position - Vector3.new(0.36, 0.26, 0.08)).Magnitude < 1e-4).to.equal(true)
			expect(model.RightUpperArm:FindFirstChild("RightShoulderRigAttachment")).to.be.ok()
			expect(model.RightUpperArm:FindFirstChild("RightElbowRigAttachment")).to.be.ok()
			expect(model.RightLowerArm:FindFirstChild("RightWristRigAttachment")).to.be.ok()
			expect(model.HumanoidRootPart:FindFirstChild("RootRigAttachment")).to.be.ok()
			expect(model.LeftEar:FindFirstChild("LeftEarBaseRigAttachment")).to.be.ok()
			expect(model.RightHand:FindFirstChild("RightGripAttachment")).to.be.ok()
			expect(model.LeftHand:FindFirstChild("LeftGripAttachment")).to.be.ok()
			expect(model.Humanoid:FindFirstChildOfClass("Animator")).to.be.ok()
			model:Destroy()
		end)

		it("is idempotent and keeps authored attachments", function()
			local model = makeTemplate()
			local authored = Instance.new("Attachment")
			authored.Name = "NeckRigAttachment"
			authored.Position = Vector3.new(9, 9, 9)
			authored.Parent = model.Head
			EmployeeSpawnSystem.prepare(model)
			expect(EmployeeSpawnSystem.prepare(model)).to.equal(0)
			expect(model.Head.NeckRigAttachment).to.equal(authored)
			expect(model.Head.NeckRigAttachment.Position).to.equal(Vector3.new(9, 9, 9))
			model:Destroy()
		end)
	end)

	describe("install", function()
		local def = {
			name = "Pippa",
			templatePath = { "Assets", "CleanupCrew", "Characters", "Pippa" },
			faces = { "Happy", "Worried", "Content" },
			defaultFace = "Happy",
			scale = 1,
		}

		it("puts a prepared copy of the template in as the StarterCharacter, leaving the template alone", function()
			local template = makeTemplate()
			local source = makeSource(template)
			local target = Instance.new("Folder")
			local ok = EmployeeSpawnSystem.install(def, source, target)
			expect(ok).to.equal(true)
			local starter = target:FindFirstChild(EmployeeConstants.STARTER_CHARACTER_NAME)
			expect(starter).to.be.ok()
			expect(starter:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE)).to.equal("Pippa")
			expect(starter.RightHand:FindFirstChild("RightGripAttachment")).to.be.ok()
			expect(template.RightHand:FindFirstChild("RightGripAttachment")).never.to.be.ok()
			source:Destroy()
			target:Destroy()
		end)

		it(
			"scales the StarterCharacter (joints, attachments and hip height) by the employee's scale, not the template",
			function()
				local template = makeTemplate()
				template.Humanoid.HipHeight = 0.3
				template.Humanoid.WalkSpeed = 16
				template.Humanoid.JumpHeight = 7.2
				local source = makeSource(template)
				local target = Instance.new("Folder")
				local big = table.clone(def)
				big.scale = 1.25
				expect(EmployeeSpawnSystem.install(big, source, target)).to.equal(true)
				local starter = target[EmployeeConstants.STARTER_CHARACTER_NAME]
				expect(starter:GetScale()).to.be.near(1.25, 1e-4)
				expect(starter.Humanoid.HipHeight).to.be.near(0.375, 1e-4)
				-- Size is cosmetic: the crew's speed and jump stay the gameplay tuning.
				expect(starter.Humanoid.WalkSpeed).to.be.near(16, 1e-4)
				expect(starter.Humanoid.JumpHeight).to.be.near(7.2, 1e-4)
				expect(starter.Head.Size.X).to.be.near(1.25, 1e-4)
				local shoulder = starter.UpperTorso.RightShoulderRigAttachment
				expect((shoulder.Position - Vector3.new(0.36, 0.26, 0.08) * 1.25).Magnitude < 1e-3).to.equal(true)
				expect(starter.RightHand:FindFirstChild("RightGripAttachment")).to.be.ok()
				expect(template:GetScale()).to.be.near(1, 1e-6)
				expect(template.Head.Size.X).to.be.near(1, 1e-6)
				source:Destroy()
				target:Destroy()
			end
		)

		it("turns the engine's overhead name and health display off on the StarterCharacter", function()
			-- A template Humanoid keeps the engine defaults (Viewer, DisplayWhenDamaged): a dead employee's
			-- health (0) then shows the stock name tag and health bar over the body.
			local template = makeTemplate()
			local source = makeSource(template)
			local target = Instance.new("Folder")
			expect(EmployeeSpawnSystem.install(def, source, target)).to.equal(true)
			local humanoid = target[EmployeeConstants.STARTER_CHARACTER_NAME].Humanoid
			expect(humanoid.DisplayDistanceType).to.equal(Enum.HumanoidDisplayDistanceType.None)
			expect(humanoid.HealthDisplayType).to.equal(Enum.HumanoidHealthDisplayType.AlwaysOff)
			expect(template.Humanoid.DisplayDistanceType).to.equal(Enum.HumanoidDisplayDistanceType.Viewer)
			source:Destroy()
			target:Destroy()
		end)

		it("replaces an employee StarterCharacter from an earlier install", function()
			local source = makeSource(makeTemplate())
			local target = Instance.new("Folder")
			EmployeeSpawnSystem.install(def, source, target)
			local first = target[EmployeeConstants.STARTER_CHARACTER_NAME]
			expect(EmployeeSpawnSystem.install(def, source, target)).to.equal(true)
			expect(first.Parent).never.to.be.ok()
			expect(#target:GetChildren()).to.equal(1)
			source:Destroy()
			target:Destroy()
		end)

		it("refuses to replace an authored, non-employee StarterCharacter", function()
			local source = makeSource(makeTemplate())
			local target = Instance.new("Folder")
			local authored = Instance.new("Model")
			authored.Name = EmployeeConstants.STARTER_CHARACTER_NAME
			authored.Parent = target
			local ok, reason = EmployeeSpawnSystem.install(def, source, target)
			expect(ok).to.equal(false)
			expect(reason).to.be.a("string")
			expect(target[EmployeeConstants.STARTER_CHARACTER_NAME]).to.equal(authored)
			source:Destroy()
			target:Destroy()
		end)

		it("reports a missing template", function()
			local source = makeSource(nil)
			local target = Instance.new("Folder")
			local ok, reason = EmployeeSpawnSystem.install(def, source, target)
			expect(ok).to.equal(false)
			expect(reason).to.be.a("string")
			expect(#target:GetChildren()).to.equal(0)
			source:Destroy()
			target:Destroy()
		end)
	end)
end
