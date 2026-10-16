local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local VacuumSkinRegistry = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumSkinRegistry)
local VisualConstants = require(ServerScriptService.Features.Vacuum.Data.VacuumVisualConstants)
local Kit = require(script.Parent.VacuumKitUtils)

return function()
	local WAND = { "WandGrip", "WandInlet", "WandTube", "WandSwivel", "FloorHead", "FloorHeadLip" }

	local function skin(name)
		return VacuumSkinRegistry.get(name)
	end

	-- A template: Backpack (with a marker part), Straps, Wand (every piece, both grips unless `noGrips`).
	local function template(name, approved, marker, noGrips)
		local model = Instance.new("Model")
		model.Name = name
		model:SetAttribute("RuntimeApproved", approved)
		local pack = Instance.new("Model")
		pack.Name = "Backpack"
		pack.Parent = model
		local mark = Instance.new("Part")
		mark.Name = marker
		mark.Parent = pack
		local straps = Instance.new("Model")
		straps.Name = "Straps"
		straps.Parent = model
		local wand = Instance.new("Model")
		wand.Name = "Wand"
		wand.Parent = model
		for _, piece in WAND do
			local part = Instance.new("Part")
			part.Name = piece
			part.Parent = wand
		end
		if not noGrips then
			for _, grip in { VisualConstants.grips.upper, VisualConstants.grips.lower } do
				local a = Instance.new("Attachment")
				a.Name = grip.name
				a.Parent = wand[grip.piece]
			end
		end
		return model
	end

	-- A fake ReplicatedStorage holding these templates under Assets.CleanupCrew.
	local function fakeRoot(templates)
		local root = Instance.new("Folder")
		local folder = root
		for _, name in VisualConstants.TEMPLATE_FOLDER do
			local child = Instance.new("Folder")
			child.Name = name
			child.Parent = folder
			folder = child
		end
		for _, model in templates do
			model.Parent = folder
		end
		return root, folder
	end

	describe("templateFor", function()
		it("finds a skin's own approved template", function()
			local root, folder =
				fakeRoot({ template("Vacuum", true, "Std"), template("VacuumBrassBellows", true, "Brass") })
			expect(Kit.templateFor(skin("BrassBellows"), root)).to.equal(folder.VacuumBrassBellows)
			expect(Kit.templateFor(skin("StandardIssue"), root)).to.equal(folder.Vacuum)
			root:Destroy()
		end)

		it("falls back to Standard Issue's template when the skin's is missing or not approved", function()
			local root, folder = fakeRoot({ template("Vacuum", true, "Std") })
			expect(Kit.templateFor(skin("BrassBellows"), root)).to.equal(folder.Vacuum)
			root:Destroy()
			local root2, folder2 =
				fakeRoot({ template("Vacuum", true, "Std"), template("VacuumBrassBellows", false, "Brass") })
			expect(Kit.templateFor(skin("BrassBellows"), root2)).to.equal(folder2.Vacuum)
			root2:Destroy()
		end)

		it("has no template when none is approved", function()
			local root = fakeRoot({ template("Vacuum", false, "Std") })
			expect(Kit.templateFor(skin("StandardIssue"), root)).to.equal(nil)
			root:Destroy()
		end)
	end)

	describe("kit", function()
		it("copies the skin's template: its pack, straps and wand pieces, leaving the template whole", function()
			local root, folder =
				fakeRoot({ template("Vacuum", true, "Std"), template("VacuumBrassBellows", true, "Brass") })
			local art = Kit.kit(skin("BrassBellows"), root)
			expect(art.kind).to.equal("approved-mesh")
			expect(art.pack:FindFirstChild("Brass")).to.be.ok()
			expect(art.straps).to.be.ok()
			for _, piece in WAND do
				expect(art.wand[piece]).to.be.ok()
				expect(art.wand[piece].Parent).to.equal(nil)
			end
			expect(folder.VacuumBrassBellows.Wand:FindFirstChild("FloorHead")).to.be.ok()
			art.pack:Destroy()
			root:Destroy()
		end)

		it("skips a template whose wand breaks the grip contract", function()
			local root =
				fakeRoot({ template("Vacuum", true, "Std"), template("VacuumBrassBellows", true, "Brass", true) })
			local art = Kit.kit(skin("BrassBellows"), root)
			-- The skin's own template is incomplete: the graybox, not a half skin.
			expect(art.kind).to.equal("native-source")
			art.pack:Destroy()
			root:Destroy()
		end)

		it("builds the graybox, with both grips, when there is no template", function()
			local root = fakeRoot({})
			local art = Kit.kit(skin("StandardIssue"), root)
			expect(art.kind).to.equal("native-source")
			expect(art.straps).to.equal(nil)
			for _, piece in WAND do
				expect(art.wand[piece]).to.be.ok()
			end
			expect(art.wand.WandGrip:FindFirstChild("GripUpper")).to.be.ok()
			expect(art.wand.WandTube:FindFirstChild("GripLower")).to.be.ok()
			art.pack:Destroy()
			root:Destroy()
		end)
	end)
end
