local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeOutfitFormulas = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeeOutfitFormulas)
local EmployeeOutfitSystem = require(script.Parent.EmployeeOutfitSystem)

return function()
	local function near(a, b)
		return (a.Position - b.Position).Magnitude < 1e-3 and a.LookVector:Dot(b.LookVector) > 0.999
	end

	local function part(parent, name, cframe, class)
		local p = Instance.new(class or "Part")
		p.Name = name
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = cframe
		p.Anchored = true
		p.Parent = parent
		return p
	end

	local function motor(name, part0, part1, c0, c1)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = part0
		m.Part1 = part1
		m.C0 = c0
		m.C1 = c1 or CFrame.identity
		m.Parent = part1
		return m
	end

	-- A small R15-shaped character: HumanoidRootPart, LowerTorso on its Root joint, UpperTorso, RightHand, a
	-- RightFoot, and a template piece (a Hat) in its pieces folder.
	local function makeCharacter()
		local model = Instance.new("Model")
		model.Name = "Character"
		local hrp = part(model, "HumanoidRootPart", CFrame.new(0, 3, 0))
		local lower = part(model, "LowerTorso", CFrame.new(0, 2.8, 0))
		local upper = part(model, "UpperTorso", CFrame.new(0, 3.6, 0))
		local hand = part(model, "RightHand", CFrame.new(1.2, 2.6, 0))
		local foot = part(model, "RightFoot", CFrame.new(0.4, 0.4, 0))
		motor("Root", hrp, lower, CFrame.new(0, -0.2, 0))
		motor("Waist", lower, upper, CFrame.new(0, 0.4, 0), CFrame.new(0, -0.4, 0))
		motor("RightWrist", upper, hand, CFrame.new(1.2, -1, 0))
		motor("RightAnkle", lower, foot, CFrame.new(0.4, -2.4, 0))
		local pieces = Instance.new("Folder")
		pieces.Name = EmployeeConstants.PIECES_FOLDER
		part(pieces, "Hat", CFrame.new(0, 5, 0))
		pieces.Parent = model
		Instance.new("Humanoid").Parent = model
		model.PrimaryPart = hrp
		return model
	end

	local function appearance(parent, name, color)
		local sa = Instance.new("SurfaceAppearance")
		sa.Name = name
		sa.Color = color
		sa.Parent = parent
		return sa
	end

	local RED, BLUE, OWN = Color3.new(1, 0, 0), Color3.new(0, 0, 1), Color3.new(0, 1, 0)

	-- An outfit at the template's size: one skinned coat mesh (StyleSlot Opaque), two Rig placeholders with a Bone
	-- each, styles Red and Blue, and a Wand prop on a RightHand Motor6D.
	local function makeOutfit()
		local outfit = Instance.new("Model")
		outfit.Name = "TestOutfit"
		local meshes = Instance.new("Folder")
		meshes.Name = EmployeeConstants.OUTFIT_MESHES
		meshes.Parent = outfit
		local coat = part(meshes, "Coat", CFrame.new(0, 3.2, 0.1), "MeshPart")
		coat:SetAttribute(EmployeeConstants.STYLE_SLOT_ATTRIBUTE, "Opaque")
		appearance(coat, "SurfaceAppearance", OWN)
		local rig = Instance.new("Folder")
		rig.Name = EmployeeConstants.OUTFIT_RIG
		rig.Parent = outfit
		for _, spec in { { "LowerTorso", CFrame.new(0, 2.8, 0) }, { "UpperTorso", CFrame.new(0, 3.6, 0) } } do
			local holder = part(rig, spec[1], spec[2])
			holder.Transparency = 1
			local bone = Instance.new("Bone")
			-- Skin bones never share a body part's name: an animation would drive them on top of their part.
			bone.Name = spec[1] .. "Bone"
			bone.CFrame = CFrame.new(0, 0.2, 0.1) * CFrame.Angles(0, 0, math.rad(10))
			bone.Parent = holder
		end
		local styles = Instance.new("Folder")
		styles.Name = EmployeeConstants.OUTFIT_STYLES
		styles.Parent = outfit
		for index, spec in { { "Red", RED }, { "Blue", BLUE } } do
			local folder = Instance.new("Folder")
			folder.Name = spec[1]
			folder:SetAttribute("Order", index)
			appearance(folder, "Opaque", spec[2])
			appearance(folder, "Wand", spec[2])
			folder.Parent = styles
		end
		local props = Instance.new("Folder")
		props.Name = EmployeeConstants.OUTFIT_PROPS
		props.Parent = outfit
		local templateHand = part(outfit, "TemplateHand", CFrame.new(1.2, 2.6, 0))
		local wand = part(props, "Wand", CFrame.new(1.2, 3.1, 0), "MeshPart")
		wand.Transparency = 1
		appearance(wand, "SurfaceAppearance", OWN)
		local joint = motor("Wand", templateHand, wand, CFrame.new(0, 0.5, 0))
		joint:SetAttribute(EmployeeConstants.PROP_HAND_ATTRIBUTE, "RightHand")
		return outfit
	end

	local function snapshot(root)
		local out = {}
		for _, d in root:GetDescendants() do
			local entry = d:GetFullName()
			if d:IsA("BasePart") then
				entry ..= tostring(d.CFrame) .. tostring(d.Size) .. tostring(d.Anchored)
			elseif d:IsA("Bone") then
				entry ..= tostring(d.CFrame)
			end
			table.insert(out, entry)
		end
		table.sort(out)
		return table.concat(out, "\n")
	end

	local function bonesIn(character)
		local out = {}
		for _, d in character:GetDescendants() do
			if d:IsA("Bone") then
				table.insert(out, d)
			end
		end
		return out
	end

	describe("fit", function()
		it("moves each bone under the body part with its name, at the scaled offset", function()
			local character, outfit = makeCharacter(), makeOutfit()
			character:ScaleTo(1.25)
			expect(EmployeeOutfitSystem.fit(character, outfit, "Red")).to.equal(true)
			for _, name in { "LowerTorso", "UpperTorso" } do
				local bone = character[name]:FindFirstChildOfClass("Bone")
				expect(bone).to.be.ok()
				expect(bone.Name).to.equal(name .. "Bone")
				local want = EmployeeOutfitFormulas.scaled(outfit.Rig[name][name .. "Bone"].CFrame, 1.25)
				expect(near(bone.CFrame, want)).to.equal(true)
				expect(bone:GetAttribute(EmployeeConstants.OUTFIT_BONE_ATTRIBUTE)).to.equal(true)
			end
			character:Destroy()
			outfit:Destroy()
		end)

		it("puts the meshes in a Folder named Outfit directly under the character, never a sub-Model", function()
			local character, outfit = makeCharacter(), makeOutfit()
			EmployeeOutfitSystem.fit(character, outfit, "Red")
			local folder = character:FindFirstChild(EmployeeConstants.OUTFIT_FOLDER)
			expect(folder).to.be.ok()
			expect(folder.ClassName).to.equal("Folder")
			expect(folder:FindFirstChild("Coat")).to.be.ok()
			for _, d in character:GetDescendants() do
				expect(d:IsA("Model") and d ~= character).to.equal(false)
			end
			character:Destroy()
			outfit:Destroy()
		end)

		it(
			"welds the meshes to LowerTorso (on HumanoidRootPart they stay rigid), weightless and out of the world",
			function()
				local character, outfit = makeCharacter(), makeOutfit()
				EmployeeOutfitSystem.fit(character, outfit, "Red")
				local coat = character.Outfit.Coat
				local weld = coat:FindFirstChildOfClass("WeldConstraint")
				expect(weld).to.be.ok()
				expect(weld.Part0).to.equal(character.LowerTorso)
				expect(weld.Part1).to.equal(coat)
				expect(coat.Anchored).to.equal(false)
				expect(coat.Massless).to.equal(true)
				expect(coat.CanCollide).to.equal(false)
				expect(coat.CanQuery).to.equal(false)
				expect(coat.CanTouch).to.equal(false)
				character:Destroy()
				outfit:Destroy()
			end
		)

		it("places and sizes the meshes from LowerTorso's rest at the character's scale", function()
			local character, outfit = makeCharacter(), makeOutfit()
			character:ScaleTo(1.25)
			EmployeeOutfitSystem.fit(character, outfit, "Red")
			local root = character.LowerTorso.Root
			local rest = EmployeeOutfitFormulas.rest(root.Part0.CFrame, root.C0, root.C1)
			local want =
				EmployeeOutfitFormulas.place(rest, outfit.Rig.LowerTorso.CFrame, outfit.Outfit.Coat.CFrame, 1.25)
			expect(near(character.Outfit.Coat.CFrame, want)).to.equal(true)
			expect((character.Outfit.Coat.Size - outfit.Outfit.Coat.Size * 1.25).Magnitude < 1e-3).to.equal(true)
			character:Destroy()
			outfit:Destroy()
		end)

		it("dresses the meshes and props in the style's looks", function()
			local character, outfit = makeCharacter(), makeOutfit()
			EmployeeOutfitSystem.fit(character, outfit, "Blue")
			local coatLooks = character.Outfit.Coat:GetChildren()
			local looks = 0
			for _, child in coatLooks do
				if child:IsA("SurfaceAppearance") then
					looks += 1
					expect(child.Color).to.equal(BLUE)
				end
			end
			expect(looks).to.equal(1)
			expect(character.EmoteProps.Wand:FindFirstChildOfClass("SurfaceAppearance").Color).to.equal(BLUE)
			character:Destroy()
			outfit:Destroy()
		end)

		it("keeps the outfit's own looks for an unknown or missing style", function()
			local character, outfit = makeCharacter(), makeOutfit()
			EmployeeOutfitSystem.fit(character, outfit, nil)
			expect(character.Outfit.Coat:FindFirstChildOfClass("SurfaceAppearance").Color).to.equal(OWN)
			character:Destroy()
			character = makeCharacter()
			EmployeeOutfitSystem.fit(character, outfit, "Gold")
			expect(character.Outfit.Coat:FindFirstChildOfClass("SurfaceAppearance").Color).to.equal(OWN)
			character:Destroy()
			outfit:Destroy()
		end)

		it("replaces an earlier fit and never doubles it", function()
			local character, outfit = makeCharacter(), makeOutfit()
			EmployeeOutfitSystem.fit(character, outfit, "Red")
			EmployeeOutfitSystem.fit(character, outfit, "Blue")
			local folders, propFolders = 0, 0
			for _, child in character:GetChildren() do
				if child.Name == EmployeeConstants.OUTFIT_FOLDER then
					folders += 1
				elseif child.Name == EmployeeConstants.PROPS_FOLDER then
					propFolders += 1
				end
			end
			expect(folders).to.equal(1)
			expect(propFolders).to.equal(1)
			expect(#bonesIn(character)).to.equal(2)
			expect(character.Outfit.Coat:FindFirstChildOfClass("SurfaceAppearance").Color).to.equal(BLUE)
			character:Destroy()
			outfit:Destroy()
		end)

		it("leaves the character untouched and returns false when the outfit is incomplete", function()
			local character = makeCharacter()
			local before = snapshot(character)
			local noRig = makeOutfit()
			noRig.Rig:Destroy()
			expect(EmployeeOutfitSystem.fit(character, noRig, "Red")).to.equal(false)
			local noMeshes = makeOutfit()
			noMeshes.Outfit:Destroy()
			expect(EmployeeOutfitSystem.fit(character, noMeshes, "Red")).to.equal(false)
			expect(snapshot(character)).to.equal(before)
			character:Destroy()
			noRig:Destroy()
			noMeshes:Destroy()
		end)

		it("leaves the character untouched and returns false when it lacks a body part the outfit needs", function()
			local character, outfit = makeCharacter(), makeOutfit()
			character.UpperTorso:Destroy()
			local before = snapshot(character)
			expect(EmployeeOutfitSystem.fit(character, outfit, "Red")).to.equal(false)
			expect(snapshot(character)).to.equal(before)
			character:Destroy()
			outfit:Destroy()
		end)

		it("refuses an outfit whose Bone is named like a body part (a clip would rotate it twice)", function()
			-- Found in Play, 2026-10-29: the stock jump drove a Bone named LeftUpperArm 109 degrees on top of its
			-- part, so the coat double-rotated.
			local character, outfit = makeCharacter(), makeOutfit()
			outfit.Rig.UpperTorso.UpperTorsoBone.Name = "UpperTorso"
			local before = snapshot(character)
			expect(EmployeeOutfitSystem.fit(character, outfit, "Red")).to.equal(false)
			expect(snapshot(character)).to.equal(before)
			character:Destroy()
			outfit:Destroy()
		end)

		it("mounts the props hidden in EmoteProps, each on a Motor6D from its hand", function()
			local character, outfit = makeCharacter(), makeOutfit()
			character:ScaleTo(1.25)
			EmployeeOutfitSystem.fit(character, outfit, "Red")
			local wand = character.EmoteProps.Wand
			expect(wand.Transparency).to.equal(1)
			expect(wand.Anchored).to.equal(false)
			expect(wand.Massless).to.equal(true)
			expect(wand.CanCollide).to.equal(false)
			local joint = wand:FindFirstChildOfClass("Motor6D")
			expect(joint.Part0).to.equal(character.RightHand)
			expect(joint.Part1).to.equal(wand)
			expect(near(joint.C0, CFrame.new(0, 0.5 * 1.25, 0))).to.equal(true)
			character:Destroy()
			outfit:Destroy()
		end)

		it("wears a prop with a holster at its body part, shown, on a Weld at the scaled offset", function()
			local character, outfit = makeCharacter(), makeOutfit()
			character:ScaleTo(1.25)
			local wand = outfit.Props.Wand
			wand:SetAttribute(EmployeeConstants.PROP_HOLSTER_ATTRIBUTE, "LowerTorso")
			wand:SetAttribute(
				EmployeeConstants.PROP_HOLSTER_OFFSET_ATTRIBUTE,
				CFrame.new(0.6, -0.2, 0) * CFrame.Angles(0, 0, 1)
			)
			EmployeeOutfitSystem.fit(character, outfit, "Red")
			local worn = character[EmployeeConstants.HOLSTER_FOLDER].Wand
			expect(worn.Transparency).to.equal(0)
			expect(worn.Anchored).to.equal(false)
			expect(worn.Massless).to.equal(true)
			expect(worn.CanCollide).to.equal(false)
			expect(worn:FindFirstChildOfClass("Motor6D")).never.to.be.ok()
			expect(worn.SurfaceAppearance.Color).to.equal(RED)
			local weld = worn:FindFirstChildOfClass("Weld")
			expect(weld.Part0).to.equal(character.LowerTorso)
			expect(weld.Part1).to.equal(worn)
			expect(near(weld.C0, CFrame.new(0.6 * 1.25, -0.2 * 1.25, 0) * CFrame.Angles(0, 0, 1))).to.equal(true)
			expect(near(worn.CFrame, character.LowerTorso.CFrame * weld.C0)).to.equal(true)
			-- the hand copy is still there, hidden, for the emote
			expect(character.EmoteProps.Wand.Transparency).to.equal(1)
			character:Destroy()
			outfit:Destroy()
		end)

		it("wears no twin for a prop without a holster, or whose holster part the character lacks", function()
			local character, outfit = makeCharacter(), makeOutfit()
			EmployeeOutfitSystem.fit(character, outfit, "Red")
			expect(#character[EmployeeConstants.HOLSTER_FOLDER]:GetChildren()).to.equal(0)
			outfit.Props.Wand:SetAttribute(EmployeeConstants.PROP_HOLSTER_ATTRIBUTE, "Tail")
			outfit.Props.Wand:SetAttribute(EmployeeConstants.PROP_HOLSTER_OFFSET_ATTRIBUTE, CFrame.identity)
			EmployeeOutfitSystem.fit(character, outfit, "Red")
			expect(#character[EmployeeConstants.HOLSTER_FOLDER]:GetChildren()).to.equal(0)
			character:Destroy()
			outfit:Destroy()
		end)

		it("replaces the worn twins on a refit", function()
			local character, outfit = makeCharacter(), makeOutfit()
			outfit.Props.Wand:SetAttribute(EmployeeConstants.PROP_HOLSTER_ATTRIBUTE, "LowerTorso")
			outfit.Props.Wand:SetAttribute(EmployeeConstants.PROP_HOLSTER_OFFSET_ATTRIBUTE, CFrame.identity)
			EmployeeOutfitSystem.fit(character, outfit, "Red")
			EmployeeOutfitSystem.fit(character, outfit, "Blue")
			local count = 0
			for _, child in character:GetChildren() do
				if child.Name == EmployeeConstants.HOLSTER_FOLDER then
					count += 1
				end
			end
			expect(count).to.equal(1)
			expect(#character[EmployeeConstants.HOLSTER_FOLDER]:GetChildren()).to.equal(1)
			expect(character[EmployeeConstants.HOLSTER_FOLDER].Wand.SurfaceAppearance.Color).to.equal(BLUE)
			character:Destroy()
			outfit:Destroy()
		end)

		it("skips a prop whose hand the character lacks", function()
			local character, outfit = makeCharacter(), makeOutfit()
			outfit.Props.Wand.Wand:SetAttribute(EmployeeConstants.PROP_HAND_ATTRIBUTE, "LeftHand")
			expect(EmployeeOutfitSystem.fit(character, outfit, "Red")).to.equal(true)
			expect(character.EmoteProps:FindFirstChild("Wand")).never.to.be.ok()
			character:Destroy()
			outfit:Destroy()
		end)

		it("hides the body parts and template pieces the outfit covers", function()
			local character, outfit = makeCharacter(), makeOutfit()
			outfit:SetAttribute(EmployeeConstants.HIDE_PARTS_ATTRIBUTE, "RightFoot, Nowhere")
			outfit:SetAttribute(EmployeeConstants.HIDE_ACCESSORIES_ATTRIBUTE, "Hat,Missing")
			EmployeeOutfitSystem.fit(character, outfit, "Red")
			expect(character.RightFoot.Transparency).to.equal(1)
			expect(character[EmployeeConstants.PIECES_FOLDER].Hat.Transparency).to.equal(1)
			expect(character.UpperTorso.Transparency).to.equal(0)
			character:Destroy()
			outfit:Destroy()
		end)

		it("never changes the source outfit", function()
			local character, outfit = makeCharacter(), makeOutfit()
			character:ScaleTo(1.25)
			local before = snapshot(outfit)
			EmployeeOutfitSystem.fit(character, outfit, "Blue")
			expect(snapshot(outfit)).to.equal(before)
			character:Destroy()
			outfit:Destroy()
		end)
	end)

	describe("mountProp", function()
		it(
			"returns a hidden, weightless copy on a Motor6D from its hand at the character's scale, unparented",
			function()
				local character, outfit = makeCharacter(), makeOutfit()
				character:ScaleTo(1.25)
				local copy = EmployeeOutfitSystem.mountProp(character, outfit.Props.Wand, nil)
				expect(copy).to.be.ok()
				expect(copy.Parent).to.equal(nil)
				expect(copy.Transparency).to.equal(1)
				expect(copy.Anchored).to.equal(false)
				expect(copy.Massless).to.equal(true)
				expect(copy.Size).to.equal(outfit.Props.Wand.Size * 1.25)
				local joint = copy:FindFirstChildOfClass("Motor6D")
				expect(joint.Part0).to.equal(character.RightHand)
				expect(joint.Part1).to.equal(copy)
				expect(near(joint.C0, CFrame.new(0, 0.5 * 1.25, 0))).to.equal(true)
				-- the template keeps its own joint and parent
				expect(outfit.Props.Wand.Wand.Part1).to.equal(outfit.Props.Wand)
				copy:Destroy()
				character:Destroy()
				outfit:Destroy()
			end
		)

		it("is nil for a prop without a Motor6D or whose hand the character lacks", function()
			local character, outfit = makeCharacter(), makeOutfit()
			outfit.Props.Wand.Wand:SetAttribute(EmployeeConstants.PROP_HAND_ATTRIBUTE, "LeftHand")
			expect(EmployeeOutfitSystem.mountProp(character, outfit.Props.Wand, nil)).never.to.be.ok()
			outfit.Props.Wand.Wand:Destroy()
			expect(EmployeeOutfitSystem.mountProp(character, outfit.Props.Wand, nil)).never.to.be.ok()
			character:Destroy()
			outfit:Destroy()
		end)
	end)

	describe("isOutfitPart", function()
		it("is true for a fitted mesh and prop, false for the body", function()
			local character, outfit = makeCharacter(), makeOutfit()
			EmployeeOutfitSystem.fit(character, outfit, "Red")
			expect(EmployeeOutfitSystem.isOutfitPart(character, character.Outfit.Coat)).to.equal(true)
			expect(EmployeeOutfitSystem.isOutfitPart(character, character.EmoteProps.Wand)).to.equal(true)
			outfit.Props.Wand:SetAttribute(EmployeeConstants.PROP_HOLSTER_ATTRIBUTE, "LowerTorso")
			outfit.Props.Wand:SetAttribute(EmployeeConstants.PROP_HOLSTER_OFFSET_ATTRIBUTE, CFrame.identity)
			EmployeeOutfitSystem.fit(character, outfit, "Red")
			local worn = character[EmployeeConstants.HOLSTER_FOLDER].Wand
			expect(EmployeeOutfitSystem.isOutfitPart(character, worn)).to.equal(true)
			expect(EmployeeOutfitSystem.isOutfitPart(character, character.UpperTorso)).to.equal(false)
			-- an emote's own prop, mounted by a client
			local mounted = Instance.new("Folder")
			mounted.Name = EmployeeConstants.EMOTE_MOUNTED_FOLDER
			mounted.Parent = character
			local own = part(mounted, "Lasso", CFrame.identity)
			expect(EmployeeOutfitSystem.isOutfitPart(character, own)).to.equal(true)
			character:Destroy()
			outfit:Destroy()
		end)
	end)
end
