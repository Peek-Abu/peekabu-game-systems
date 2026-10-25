local EmployeePreviewSystem = require(script.Parent.EmployeePreviewSystem)

return function()
	local function part(model, name, y)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(1, 1, 1)
		p.Position = Vector3.new(0, y, 0)
		p.Parent = model
		return p
	end

	-- A tiny rig (root -> torso) with a Humanoid, saved anchored like the art.
	local function template(name)
		local model = Instance.new("Model")
		model.Name = name
		Instance.new("Humanoid").Parent = model
		local root = part(model, "HumanoidRootPart", 2)
		root.Anchored = true
		local torso = part(model, "LowerTorso", 2)
		model.PrimaryPart = root
		local m = Instance.new("Motor6D")
		m.Name = "Root"
		m.Part0 = root
		m.Part1 = torso
		m.Parent = torso
		local script = Instance.new("LocalScript")
		script.Name = "Leftover"
		script.Parent = model
		return model
	end

	-- ReplicatedStorage-shaped source: Assets/CleanupCrew/Characters/<name>
	local function source(names)
		local root = Instance.new("Folder")
		local current = root
		for _, name in { "Assets", "CleanupCrew", "Characters" } do
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = current
			current = folder
		end
		for _, name in names do
			template(name).Parent = current
		end
		return root
	end

	afterEach(function()
		EmployeePreviewSystem.reset()
	end)

	it("builds a static, posed copy: every part anchored, no Animator, no scripts", function()
		local src = source({ "Pippa" })
		local model = EmployeePreviewSystem.static("Pippa", nil, src)
		expect(model).to.be.ok()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				expect(d.Anchored).to.equal(true)
			end
			expect(d:IsA("Animator")).to.equal(false)
			expect(d:IsA("LuaSourceContainer")).to.equal(false)
		end
		model:Destroy()
		src:Destroy()
	end)

	it("builds a live copy ready to animate: an Animator, the root held, the body free", function()
		local src = source({ "Pippa" })
		local model = EmployeePreviewSystem.live("Pippa", nil, src)
		expect(model).to.be.ok()
		expect(model:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")).to.be.ok()
		expect(model.HumanoidRootPart.Anchored).to.equal(true)
		expect(model.LowerTorso.Anchored).to.equal(false)
		expect(model:FindFirstChild("Leftover")).never.to.be.ok()
		model:Destroy()
		src:Destroy()
	end)

	it("allows at most two live previews at once, and frees a slot when one is destroyed", function()
		local src = source({ "Pippa" })
		local a = EmployeePreviewSystem.live("Pippa", nil, src)
		local b = EmployeePreviewSystem.live("Pippa", nil, src)
		expect(a).to.be.ok()
		expect(b).to.be.ok()
		expect(EmployeePreviewSystem.live("Pippa", nil, src)).never.to.be.ok()
		expect(EmployeePreviewSystem.liveCount()).to.equal(2)
		a:Destroy()
		task.wait()
		expect(EmployeePreviewSystem.liveCount()).to.equal(1)
		local c = EmployeePreviewSystem.live("Pippa", nil, src)
		expect(c).to.be.ok()
		b:Destroy()
		c:Destroy()
		src:Destroy()
	end)

	describe("outfit", function()
		local CosmeticOutfitRules =
			require(game:GetService("ReplicatedStorage").Shared.Features.Cosmetic.Rules.CosmeticOutfitRules)
		local CosmeticConstants =
			require(game:GetService("ReplicatedStorage").Shared.Features.Cosmetic.Data.CosmeticConstants)
		local function pippa()
			return CosmeticOutfitRules.current(CosmeticConstants.defaultLoadout(), function()
				return false
			end)
		end

		-- The player's own character as the server built it: dressed, a lanyard, a script, a tool.
		local function character(employee, skin)
			local model = template(employee)
			model:SetAttribute("EmployeeName", employee)
			model:SetAttribute("EmployeeSkin", skin)
			local lanyard = Instance.new("Part")
			lanyard.Name = "Lanyard"
			lanyard.Parent = model
			-- Worn: welded to the body (a loose part never makes it into a posed copy).
			local weld = Instance.new("Weld")
			weld.Part0 = model.LowerTorso
			weld.Part1 = lanyard
			weld.Parent = lanyard
			Instance.new("Tool").Parent = model
			model.Archivable = false
			return model
		end

		it("clones your own character when it wears the outfit, keeping what the server put on it", function()
			local src = source({ "Pippa" })
			local mine = character("Pippa", "Default")
			local model, moving = EmployeePreviewSystem.outfit(pippa(), src, mine, false)
			expect(moving).to.equal(false)
			expect(model:FindFirstChild("Lanyard", true)).to.be.ok()
			expect(model:FindFirstChildOfClass("Tool")).never.to.be.ok()
			expect(mine.Archivable).to.equal(false)
			for _, d in model:GetDescendants() do
				expect(d:IsA("LuaSourceContainer")).to.equal(false)
			end
			model:Destroy()
			mine:Destroy()
			src:Destroy()
		end)

		it("dresses the template when your character is someone else, and goes live when asked", function()
			local src = source({ "Pippa" })
			local other = character("Cappy", "Default")
			local model, moving = EmployeePreviewSystem.outfit(pippa(), src, other, true)
			expect(moving).to.equal(true)
			expect(model:FindFirstChild("Lanyard")).never.to.be.ok()
			expect(model:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")).to.be.ok()
			expect(EmployeePreviewSystem.liveCount()).to.equal(1)
			model:Destroy()
			other:Destroy()
			src:Destroy()
		end)
	end)

	it("returns nil for an employee with no art or no registry entry", function()
		local src = source({})
		expect(EmployeePreviewSystem.static("Pippa", nil, src)).never.to.be.ok()
		expect(EmployeePreviewSystem.static("Nobody", nil, src)).never.to.be.ok()
		src:Destroy()
	end)

	it("names the idle clip a live preview plays", function()
		expect(EmployeePreviewSystem.idleOf("Pippa")).to.equal("pippaidle")
		expect(EmployeePreviewSystem.idleOf("Nobody")).never.to.be.ok()
	end)
end
