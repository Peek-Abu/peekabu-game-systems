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

	-- Adds Assets/CleanupCrew/Outfits/PippaBubbleBuddy to `src`: one coat mesh (StyleSlot Opaque), a LowerTorso bone,
	-- and the first two styles, each an "Opaque" look in its own colour.
	local STYLE_COLOURS = { BlueYellow = Color3.new(0, 0, 1), PinkTurquoise = Color3.new(1, 0, 1) }
	local function withOutfit(src)
		local outfits = Instance.new("Folder")
		outfits.Name = "Outfits"
		outfits.Parent = src.Assets.CleanupCrew
		local outfit = Instance.new("Model")
		outfit.Name = "PippaBubbleBuddy"
		local meshes = Instance.new("Folder")
		meshes.Name = "Outfit"
		meshes.Parent = outfit
		local coat = Instance.new("MeshPart")
		coat.Name = "Coat"
		coat:SetAttribute("StyleSlot", "Opaque")
		coat.Parent = meshes
		local rig = Instance.new("Folder")
		rig.Name = "Rig"
		rig.Parent = outfit
		local holder = Instance.new("Part")
		holder.Name = "LowerTorso"
		holder.Parent = rig
		local bone = Instance.new("Bone")
		bone.Name = "LowerTorsoBone"
		bone.Parent = holder
		local styles = Instance.new("Folder")
		styles.Name = "Styles"
		styles.Parent = outfit
		for name, colour in STYLE_COLOURS do
			local folder = Instance.new("Folder")
			folder.Name = name
			local look = Instance.new("SurfaceAppearance")
			look.Name = "Opaque"
			look.Color = colour
			look.Parent = folder
			folder.Parent = styles
		end
		outfit.Parent = outfits
		return src
	end

	local function coatColour(model)
		local outfit = model:FindFirstChild("Outfit")
		local coat = outfit and outfit:FindFirstChild("Coat")
		local look = coat and coat:FindFirstChildOfClass("SurfaceAppearance")
		return look and look.Color
	end

	describe("styles", function()
		it("dresses a static preview in the asked colour style", function()
			local src = withOutfit(source({ "Pippa" }))
			local first = EmployeePreviewSystem.static("Pippa", "BubbleBuddy", src, nil, 1)
			local second = EmployeePreviewSystem.static("Pippa", "BubbleBuddy", src, nil, 2)
			expect(coatColour(first)).to.equal(STYLE_COLOURS.BlueYellow)
			expect(coatColour(second)).to.equal(STYLE_COLOURS.PinkTurquoise)
			first:Destroy()
			second:Destroy()
			src:Destroy()
		end)

		it("dresses a live preview in the asked colour style", function()
			local src = withOutfit(source({ "Pippa" }))
			local model = EmployeePreviewSystem.live("Pippa", "BubbleBuddy", src, 2)
			expect(coatColour(model)).to.equal(STYLE_COLOURS.PinkTurquoise)
			model:Destroy()
			src:Destroy()
		end)
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

	it("frees a live slot at once on release, so a rebuild in the same frame is still live", function()
		-- Destroying alone frees the slot only when the deferred Destroying signal runs (next frame): a viewport that
		-- rebuilt at once (a style chip) got the frozen copy (owner report, 2026-10-29).
		local src = source({ "Pippa" })
		local a = EmployeePreviewSystem.live("Pippa", nil, src)
		local b = EmployeePreviewSystem.live("Pippa", nil, src)
		EmployeePreviewSystem.release(b)
		expect(EmployeePreviewSystem.liveCount()).to.equal(1)
		expect(b.Parent).to.equal(nil)
		local c = EmployeePreviewSystem.live("Pippa", nil, src)
		expect(c).to.be.ok()
		-- Releasing twice, or a model that is not live, changes nothing.
		EmployeePreviewSystem.release(b)
		EmployeePreviewSystem.release(Instance.new("Model"))
		expect(EmployeePreviewSystem.liveCount()).to.equal(2)
		a:Destroy()
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

		it("dresses the template instead of cloning your character when it wears another colour style", function()
			local src = withOutfit(source({ "Pippa" }))
			local mine = character("Pippa", "BubbleBuddy")
			mine:SetAttribute("EmployeeSkinStyle", 1)
			local look = pippa()
			look.look.skin = "Pippa.BubbleBuddy"
			look.look.style = 2
			local model = EmployeePreviewSystem.outfit(look, src, mine, false)
			-- A clone would carry the server's lanyard; the dressed template does not.
			expect(model:FindFirstChild("Lanyard", true)).never.to.be.ok()
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

	it("plays a skin's own showcase idle when it has one, else the employee's", function()
		expect(EmployeePreviewSystem.idleOf("Pippa", "BubbleBuddy")).to.equal("pippaidle")
		expect(EmployeePreviewSystem.idleOf("Prickles", "Sheriff")).to.equal("pricklessheriffidle")
		expect(EmployeePreviewSystem.idleOf("Pippa", "Default")).to.equal("pippaidle")
		expect(EmployeePreviewSystem.idleOf("Pippa", "NoSuchSkin")).to.equal("pippaidle")
	end)

	it("reveals every skin with the employee's hire reveal, worn in that skin (no skin has its own yet)", function()
		-- the Legendaries too, for now (owner, 2026-10-29)
		expect(EmployeePreviewSystem.revealOf("Pippa", "BubbleBuddy")).to.equal("pippahirereveal")
		expect(EmployeePreviewSystem.revealOf("Prickles", "Sheriff")).to.equal("prickleshirereveal")
		expect(EmployeePreviewSystem.revealOf("Cappy", "PJ")).never.to.be.ok()
		-- a skin without its own clip, and a hire (no skin): the hire reveal, worn in that skin
		expect(EmployeePreviewSystem.revealOf("Pippa", "Default")).to.equal("pippahirereveal")
		expect(EmployeePreviewSystem.revealOf("Prickles", nil)).to.equal("prickleshirereveal")
		-- Cappy's hire reveal is not in yet: nothing, so the preview stays on his idle
		expect(EmployeePreviewSystem.revealOf("Cappy", "Default")).never.to.be.ok()
		expect(EmployeePreviewSystem.revealOf("Nobody", nil)).never.to.be.ok()
	end)

	it("names the clip an emote item loops in a preview, only for an emote with a clip", function()
		expect(EmployeePreviewSystem.emoteOf("Pippa.Bubbles")).to.equal("emote:Pippa.Bubbles")
		expect(EmployeePreviewSystem.emoteOf("Prickles.Lasso")).to.equal("emote:Prickles.Lasso")
		-- an emote whose clip is not made yet, a skin, an unknown id
		expect(EmployeePreviewSystem.emoteOf("Pippa.Wave")).never.to.be.ok()
		expect(EmployeePreviewSystem.emoteOf("Pippa.BubbleBuddy")).never.to.be.ok()
		expect(EmployeePreviewSystem.emoteOf("Nobody.Nothing")).never.to.be.ok()
		expect(EmployeePreviewSystem.EMOTE_PAUSE > 0).to.equal(true)
	end)
end
