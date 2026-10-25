local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumSkinRegistry = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumSkinRegistry)
local VacuumPreviewSystem = require(script.Parent.VacuumPreviewSystem)

return function()
	local function part(parent, name, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(1, 1, 1)
		p.Color = color or Color3.new(1, 1, 1)
		p.Anchored = true
		p.Parent = parent
		return p
	end

	local function model(parent, name)
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = parent
		return m
	end

	-- A skin template under Assets/CleanupCrew: Backpack, Straps, Wand pieces, in one colour.
	local function source(skins)
		local root = Instance.new("Folder")
		local assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = root
		local cc = Instance.new("Folder")
		cc.Name = "CleanupCrew"
		cc.Parent = assets
		for name, color in skins do
			local template = model(cc, name)
			template:SetAttribute("RuntimeApproved", true)
			local pack = model(template, "Backpack")
			part(pack, "Canister", color)
			pack.PrimaryPart = pack:FindFirstChild("Canister")
			local straps = model(template, "Straps")
			part(straps, "Strap", color)
			straps.PrimaryPart = straps:FindFirstChild("Strap")
			local wand = model(template, "Wand")
			part(wand, "WandGrip", color)
			part(wand, "WandTube", color)
		end
		return root
	end

	-- A worn pack like VacuumVisualSystem builds one, in Standard Issue's colour.
	local function worn(color)
		local character = Instance.new("Model")
		local torso = part(character, "UpperTorso")
		local backpack = model(character, VacuumConstants.BACKPACK_NAME)
		backpack:SetAttribute("VacuumSkin", "StandardIssue")
		local pack = model(backpack, "Pack")
		part(pack, "Canister", color)
		pack.PrimaryPart = pack:FindFirstChild("Canister")
		local straps = model(backpack, "Straps")
		part(straps, "Strap", color)
		straps.PrimaryPart = straps:FindFirstChild("Strap")
		local stowed = model(backpack, "StowedWand")
		local tube = part(stowed, "WandTube", color)
		tube.Size = Vector3.new(0.2, 3, 0.2)
		part(stowed, "WandGrip", color)
		local anchor = part(backpack, "PackAnchor")
		local beam = Instance.new("Beam")
		beam.Parent = backpack
		return character, backpack, torso, anchor
	end

	local GREY = Color3.fromRGB(10, 10, 10)
	local BRASS = Color3.fromRGB(200, 150, 50)
	local brass = VacuumSkinRegistry.get("BrassBellows")
	local standardTemplate = VacuumSkinRegistry.get("StandardIssue").template

	describe("swap", function()
		it("puts another skin's art on a cloned character's pack, keeping where and how big each piece is", function()
			local src = source({ [standardTemplate] = GREY, [brass.template] = BRASS })
			local character, backpack = worn(GREY)
			expect(VacuumPreviewSystem.swap(character, brass, src)).to.equal(true)
			expect(backpack:GetAttribute("VacuumSkin")).to.equal("BrassBellows")
			expect(backpack.Pack.Canister.Color).to.equal(BRASS)
			expect(backpack.Straps.Strap.Color).to.equal(BRASS)
			expect(backpack.StowedWand.WandTube.Color).to.equal(BRASS)
			-- The telescoped tube keeps its length.
			expect(backpack.StowedWand.WandTube.Size).to.equal(Vector3.new(0.2, 3, 0.2))
			expect(#backpack.StowedWand:GetChildren()).to.equal(2)
			expect(backpack:FindFirstChildOfClass("Beam").Texture).to.equal(brass.hoseTexture)
		end)

		it("welds the new pieces so a live (animated) preview carries them", function()
			local src = source({ [brass.template] = BRASS })
			local character, backpack = worn(GREY)
			VacuumPreviewSystem.swap(character, brass, src)
			local canister = backpack.Pack.Canister
			expect(canister.Anchored).to.equal(false)
			expect(canister:FindFirstChildOfClass("WeldConstraint")).to.be.ok()
		end)

		it("changes nothing without a pack, an approved template, or when it already wears that skin", function()
			local src = source({ [brass.template] = BRASS })
			expect(VacuumPreviewSystem.swap(Instance.new("Model"), brass, src)).to.equal(false)
			local character, backpack = worn(GREY)
			expect(VacuumPreviewSystem.swap(character, brass, source({}))).to.equal(false)
			expect(backpack.Pack.Canister.Color).to.equal(GREY)
			backpack:SetAttribute("VacuumSkin", "BrassBellows")
			expect(VacuumPreviewSystem.swap(character, brass, src)).to.equal(false)
		end)
	end)

	describe("alone", function()
		it("gives the skin's canister on its own, anchored, for a card", function()
			local src = source({ [brass.template] = BRASS })
			local pack = VacuumPreviewSystem.alone(brass, src)
			expect(pack).to.be.ok()
			expect(pack.Canister.Color).to.equal(BRASS)
			expect(pack.Canister.Anchored).to.equal(true)
			expect(VacuumPreviewSystem.alone(brass, source({}))).never.to.be.ok()
		end)
	end)
end
