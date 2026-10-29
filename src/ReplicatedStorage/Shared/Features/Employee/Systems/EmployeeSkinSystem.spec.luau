local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeSkinSystem = require(script.Parent.EmployeeSkinSystem)

return function()
	local ORIGINAL = "rbxassetid://100"

	local function meshPart(model, name)
		local part = Instance.new("MeshPart")
		part.Name = name
		part.TextureID = ORIGINAL
		part.Parent = model
		return part
	end

	local function faceFolder(model, name, marker)
		local folder = Instance.new("Folder")
		folder.Name = name
		folder:SetAttribute("Marker", marker)
		for _, face in { "Happy", "Worried", "Content" } do
			local appearance = Instance.new("SurfaceAppearance")
			appearance.Name = face
			appearance.Parent = folder
		end
		folder.Parent = model
		return folder
	end

	local function makeCharacter()
		local model = Instance.new("Model")
		Instance.new("Humanoid").Parent = model
		local head = meshPart(model, "Head")
		local arm = meshPart(model, "RightUpperArm")
		local plate = meshPart(model, EmployeeConstants.FACE_PLATE)
		plate.TextureID = ""
		faceFolder(model, EmployeeConstants.FACES_FOLDER, "own")
		return model, head, arm, plate
	end

	local function skin(palette, facesFolder, accessories)
		return { name = "Test", paletteTextureId = palette, facesFolder = facesFolder, accessories = accessories or {} }
	end

	describe("apply", function()
		it("puts the palette on every MeshPart but the FacePlate", function()
			local model, head, arm, plate = makeCharacter()
			local result = EmployeeSkinSystem.apply(model, skin("rbxassetid://200"), nil)
			expect(result.textured).to.equal(2)
			expect(head.TextureID).to.equal("rbxassetid://200")
			expect(arm.TextureID).to.equal("rbxassetid://200")
			expect(plate.TextureID).to.equal("")
			model:Destroy()
		end)

		it("changes nothing when the skin's palette is missing (art pending)", function()
			local model, head = makeCharacter()
			local result = EmployeeSkinSystem.apply(model, skin(nil), nil)
			expect(result.textured).to.equal(0)
			expect(result.facesSwapped).to.equal(false)
			expect(result.accessories).to.equal(0)
			expect(head.TextureID).to.equal(ORIGINAL)
			expect(model[EmployeeConstants.FACES_FOLDER]:GetAttribute("Marker")).to.equal("own")
			model:Destroy()
		end)

		it("swaps in the skin's face set when the character carries it", function()
			local model = makeCharacter()
			faceFolder(model, "SpecialFaces", "special")
			local result = EmployeeSkinSystem.apply(model, skin(nil, "SpecialFaces"), nil)
			expect(result.facesSwapped).to.equal(true)
			local faces = model:FindFirstChild(EmployeeConstants.FACES_FOLDER)
			expect(faces:GetAttribute("Marker")).to.equal("special")
			expect(model:FindFirstChild("SpecialFaces")).never.to.be.ok()
			model:Destroy()
		end)

		it("keeps the own faces when the skin's face set is missing", function()
			local model = makeCharacter()
			local result = EmployeeSkinSystem.apply(model, skin(nil, "Nowhere"), nil)
			expect(result.facesSwapped).to.equal(false)
			expect(model[EmployeeConstants.FACES_FOLDER]:GetAttribute("Marker")).to.equal("own")
			model:Destroy()
		end)

		it("adds the skin's accessories found in the source, skipping missing ones", function()
			local model = makeCharacter()
			local source = Instance.new("Folder")
			local hat = Instance.new("Accessory")
			hat.Name = "Cap"
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Parent = hat
			hat.Parent = source
			local result = EmployeeSkinSystem.apply(model, skin(nil, nil, { "Cap", "Nope" }), source)
			expect(result.accessories).to.equal(1)
			expect(model:FindFirstChild("Cap")).to.be.ok()
			expect(source:FindFirstChild("Cap")).to.be.ok()
			model:Destroy()
			source:Destroy()
		end)

		it("fits a fitted-gear Model accessory onto its mount part (glasses on the head)", function()
			local model, head = makeCharacter()
			head.Anchored = true
			local source = Instance.new("Folder")
			local glasses = Instance.new("Model")
			glasses.Name = "Glasses"
			local frame = Instance.new("Part")
			frame.Name = "Frame"
			frame.Parent = glasses
			glasses:SetAttribute(EmployeeConstants.GEAR_MOUNT_ATTRIBUTE, "Head")
			glasses.Parent = source
			local result = EmployeeSkinSystem.apply(model, skin(nil, nil, { "Glasses" }), source)
			expect(result.accessories).to.equal(1)
			local fitted = model:FindFirstChild("Glasses")
			expect(fitted).to.be.ok()
			expect(fitted.Frame:FindFirstChildOfClass("WeldConstraint").Part0).to.equal(head)
			model:Destroy()
			source:Destroy()
		end)
	end)

	describe("outfit", function()
		-- A character with a LowerTorso on its Root joint, and an Outfits source holding a one-mesh outfit "Coat" in a
		-- Blue style, with a Wand prop.
		local function outfitted()
			local model, head = makeCharacter()
			local hrp = Instance.new("Part")
			hrp.Name = "HumanoidRootPart"
			hrp.Anchored = true
			hrp.Parent = model
			local lower = meshPart(model, "LowerTorso")
			lower.Anchored = true
			local root = Instance.new("Motor6D")
			root.Name = "Root"
			root.Part0 = hrp
			root.Part1 = lower
			root.Parent = lower
			local source = Instance.new("Folder")
			local outfit = Instance.new("Model")
			outfit.Name = "Coat"
			local meshes = Instance.new("Folder")
			meshes.Name = EmployeeConstants.OUTFIT_MESHES
			meshes.Parent = outfit
			local coat = meshPart(meshes, "CoatMesh")
			coat:SetAttribute(EmployeeConstants.STYLE_SLOT_ATTRIBUTE, "Opaque")
			local rig = Instance.new("Folder")
			rig.Name = EmployeeConstants.OUTFIT_RIG
			rig.Parent = outfit
			local holder = Instance.new("Part")
			holder.Name = "LowerTorso"
			holder.Parent = rig
			local bone = Instance.new("Bone")
			bone.Name = "LowerTorsoBone"
			bone.Parent = holder
			local styles = Instance.new("Folder")
			styles.Name = EmployeeConstants.OUTFIT_STYLES
			styles.Parent = outfit
			local blue = Instance.new("Folder")
			blue.Name = "Blue"
			local look = Instance.new("SurfaceAppearance")
			look.Name = "Opaque"
			look.Parent = blue
			blue.Parent = styles
			local props = Instance.new("Folder")
			props.Name = EmployeeConstants.OUTFIT_PROPS
			props.Parent = outfit
			local wand = meshPart(props, "Wand")
			local joint = Instance.new("Motor6D")
			joint.Part1 = wand
			joint:SetAttribute(EmployeeConstants.PROP_HAND_ATTRIBUTE, "RightUpperArm")
			joint.Parent = wand
			outfit.Parent = source
			return model, head, source
		end

		local function outfitSkin(styles)
			local def = skin(nil)
			def.outfit = "Coat"
			def.styles = styles
			return def
		end

		local STYLES = {
			{ folder = "Blue", paletteTextureId = "rbxassetid://501" },
			{ folder = "Pink", paletteTextureId = "rbxassetid://502" },
		}

		it("fits the skin's outfit in the chosen style and reports it", function()
			local model, _, source = outfitted()
			local result = EmployeeSkinSystem.apply(model, outfitSkin(STYLES), nil, 1, source)
			expect(result.outfit).to.equal(true)
			local fitted = model:FindFirstChild(EmployeeConstants.OUTFIT_FOLDER)
			expect(fitted).to.be.ok()
			expect(fitted.CoatMesh:FindFirstChildOfClass("SurfaceAppearance")).to.be.ok()
			model:Destroy()
			source:Destroy()
		end)

		it("gives the body the style's palette and skips the outfit meshes and the props", function()
			local model, head, source = outfitted()
			local result = EmployeeSkinSystem.apply(model, outfitSkin(STYLES), nil, 2, source)
			expect(head.TextureID).to.equal("rbxassetid://502")
			expect(model.Outfit.CoatMesh.TextureID).to.equal(ORIGINAL)
			expect(model.EmoteProps.Wand.TextureID).to.equal(ORIGINAL)
			-- Head, RightUpperArm and LowerTorso: the body, never the outfit.
			expect(result.textured).to.equal(3)
			model:Destroy()
			source:Destroy()
		end)

		it("reports no outfit without a source, or for an outfit the source lacks", function()
			local model, _, source = outfitted()
			expect(EmployeeSkinSystem.apply(model, outfitSkin(STYLES), nil, 1, nil).outfit).to.equal(false)
			local missing = outfitSkin(STYLES)
			missing.outfit = "Nowhere"
			expect(EmployeeSkinSystem.apply(model, missing, nil, 1, source).outfit).to.equal(false)
			expect(model:FindFirstChild(EmployeeConstants.OUTFIT_FOLDER)).never.to.be.ok()
			model:Destroy()
			source:Destroy()
		end)

		it("leaves exactly one outfit when the skin is applied twice (a re-dress never doubles the coat)", function()
			local model, _, source = outfitted()
			EmployeeSkinSystem.apply(model, outfitSkin(STYLES), nil, 1, source)
			EmployeeSkinSystem.apply(model, outfitSkin(STYLES), nil, 2, source)
			local outfits, props, meshes, bones = 0, 0, 0, 0
			for _, child in model:GetChildren() do
				if child.Name == EmployeeConstants.OUTFIT_FOLDER then
					outfits += 1
					meshes += #child:GetChildren()
				elseif child.Name == EmployeeConstants.PROPS_FOLDER then
					props += 1
				end
			end
			for _, d in model:GetDescendants() do
				if d:IsA("Bone") then
					bones += 1
				end
			end
			expect(outfits).to.equal(1)
			expect(props).to.equal(1)
			expect(meshes).to.equal(1)
			expect(bones).to.equal(1)
			model:Destroy()
			source:Destroy()
		end)

		it("reports no outfit for a skin without one", function()
			local model, _, source = outfitted()
			expect(EmployeeSkinSystem.apply(model, skin("rbxassetid://200"), nil, 1, source).outfit).to.equal(false)
			model:Destroy()
			source:Destroy()
		end)
	end)

	describe("pieces", function()
		-- A character whose own clothes sit in its pieces folder: a Hoodie model of two MeshParts and a plain Shorts part.
		local function dressed()
			local model, head = makeCharacter()
			local pieces = Instance.new("Folder")
			pieces.Name = EmployeeConstants.PIECES_FOLDER
			local hoodie = Instance.new("Model")
			hoodie.Name = "Hoodie"
			local torso = meshPart(hoodie, "Hoodie_UpperTorso")
			local sleeve = meshPart(hoodie, "Hoodie_LeftUpperArm")
			hoodie.Parent = pieces
			local shorts = meshPart(pieces, "Shorts")
			shorts.Color = Color3.new(0, 0, 0)
			pieces.Parent = model
			return model, head, torso, sleeve, shorts
		end

		local function pieceSkin(palette, piecePalettes, pieceColors)
			local def = skin(palette)
			def.piecePalettes = piecePalettes
			def.pieceColors = pieceColors
			return def
		end

		it("keeps the body palette off the clothes", function()
			local model, head, torso, _, shorts = dressed()
			local result = EmployeeSkinSystem.apply(model, pieceSkin("rbxassetid://200"), nil)
			expect(result.textured).to.equal(2)
			expect(head.TextureID).to.equal("rbxassetid://200")
			expect(torso.TextureID).to.equal(ORIGINAL)
			expect(shorts.TextureID).to.equal(ORIGINAL)
			model:Destroy()
		end)

		it("puts a piece's palette on every MeshPart of that piece", function()
			local model, head, torso, sleeve = dressed()
			local result = EmployeeSkinSystem.apply(model, pieceSkin(nil, { Hoodie = "rbxassetid://300" }), nil)
			expect(result.pieces).to.equal(2)
			expect(torso.TextureID).to.equal("rbxassetid://300")
			expect(sleeve.TextureID).to.equal("rbxassetid://300")
			expect(head.TextureID).to.equal(ORIGINAL)
			model:Destroy()
		end)

		it("paints a plain piece in its colour", function()
			local model, _, _, _, shorts = dressed()
			local lilac = Color3.fromRGB(196, 148, 232)
			local result = EmployeeSkinSystem.apply(model, pieceSkin(nil, nil, { Shorts = lilac }), nil)
			expect(result.pieces).to.equal(1)
			expect(shorts.Color).to.equal(lilac)
			model:Destroy()
		end)

		it("skips a missing piece and a malformed piece palette", function()
			local model, _, torso = dressed()
			local result = EmployeeSkinSystem.apply(
				model,
				pieceSkin(nil, { Hoodie = "not-an-id", Cape = "rbxassetid://400" }, { Gloves = Color3.new(1, 1, 1) }),
				nil
			)
			expect(result.pieces).to.equal(0)
			expect(torso.TextureID).to.equal(ORIGINAL)
			model:Destroy()
		end)
	end)
end
