local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeCharacterSystem = require(script.Parent.EmployeeCharacterSystem)

return function()
	local function part(model, name, y, size)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size or Vector3.new(1, 1, 1)
		p.Position = Vector3.new(0, y, 0)
		p.Parent = model
		return p
	end

	-- A tiny rig saved like the Prickles art: root anchored, HipHeight 0, standing with its foot's bottom at y 0.
	local function makeTemplate(name, hipHeight)
		local model = Instance.new("Model")
		model.Name = name
		local humanoid = Instance.new("Humanoid")
		humanoid.HipHeight = hipHeight or 0
		humanoid.Parent = model
		local root = part(model, "HumanoidRootPart", 2)
		root.Anchored = true
		local lower = part(model, "LowerTorso", 2)
		part(model, "LeftFoot", 0.5)
		model.PrimaryPart = root
		local m = Instance.new("Motor6D")
		m.Name = "Root"
		m.Part0 = root
		m.Part1 = lower
		m.Parent = lower
		return model
	end

	local function makeSource(templates)
		local source = Instance.new("Folder")
		local current = source
		for _, name in { "Assets", "CleanupCrew", "Characters" } do
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = current
			current = folder
		end
		for _, template in templates do
			template.Parent = current
		end
		return source
	end

	local function defFor(name, extra)
		local def = {
			name = name,
			templatePath = { "Assets", "CleanupCrew", "Characters", name },
			scale = 1,
		}
		for k, v in extra or {} do
			def[k] = v
		end
		return def
	end

	local function makeScripts()
		local folder = Instance.new("Folder")
		local animate = Instance.new("LocalScript")
		animate.Name = "Animate"
		animate.Parent = folder
		return folder
	end

	afterEach(function()
		EmployeeCharacterSystem.clearCache()
	end)

	it("builds a fresh, named, un-anchored character from the art, with the character scripts", function()
		local source = makeSource({ makeTemplate("Prickles_v4") })
		source.Assets.CleanupCrew.Characters.Prickles_v4.Name = "Prickles"
		local built = EmployeeCharacterSystem.build(defFor("Prickles"), source, makeScripts())
		expect(built).to.be.ok()
		expect(built:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE)).to.equal("Prickles")
		for _, d in built:GetDescendants() do
			if d:IsA("BasePart") then
				expect(d.Anchored).to.equal(false)
			end
		end
		expect(built:FindFirstChild("Animate")).to.be.ok()
		expect(built.Humanoid.DisplayDistanceType).to.equal(Enum.HumanoidDisplayDistanceType.None)
		expect(built.Humanoid:FindFirstChildOfClass("Animator")).to.be.ok()
		local second = EmployeeCharacterSystem.build(defFor("Prickles"), source, makeScripts())
		expect(second).never.to.equal(built)
		source:Destroy()
	end)

	it("fits HipHeight when the art was saved with 0, and keeps an authored one", function()
		local source = makeSource({ makeTemplate("Cappy", 0), makeTemplate("Pippa", 0.3) })
		local cappy = EmployeeCharacterSystem.build(defFor("Cappy"), source, makeScripts())
		-- root bottom 1.5, foot bottom 0
		expect(cappy.Humanoid.HipHeight).to.be.near(1.5, 1e-3)
		local pippa = EmployeeCharacterSystem.build(defFor("Pippa"), source, makeScripts())
		expect(pippa.Humanoid.HipHeight).to.be.near(0.3, 1e-3)
		source:Destroy()
	end)

	it("names its footstep set when the employee borrows one", function()
		local source = makeSource({ makeTemplate("Cappy") })
		local built = EmployeeCharacterSystem.build(defFor("Cappy", { footstepSet = "pippa" }), source, makeScripts())
		expect(built:GetAttribute(EmployeeConstants.FOOTSTEP_SET_ATTRIBUTE)).to.equal("pippa")
		source:Destroy()
	end)

	it("scales the art once, keeping walk speed and jump (gameplay tuning)", function()
		local template = makeTemplate("Cappy")
		template.Humanoid.WalkSpeed = 16
		local source = makeSource({ template })
		local built = EmployeeCharacterSystem.build(defFor("Cappy", { scale = 2 }), source, makeScripts())
		expect(built.HumanoidRootPart.Size.X).to.be.near(2, 1e-3)
		expect(built.Humanoid.WalkSpeed).to.equal(16)
		expect(EmployeeCharacterSystem.prepared(defFor("Cappy", { scale = 2 }), source)).to.equal(
			EmployeeCharacterSystem.prepared(defFor("Cappy", { scale = 2 }), source)
		)
		source:Destroy()
	end)

	it("returns nil when this place has no art for the employee", function()
		local source = makeSource({})
		expect(EmployeeCharacterSystem.build(defFor("Cappy"), source, makeScripts())).never.to.be.ok()
		source:Destroy()
	end)
end
