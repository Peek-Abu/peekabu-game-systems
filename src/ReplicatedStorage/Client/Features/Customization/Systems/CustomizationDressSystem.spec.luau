--!strict
--[=[
	Unit tests for CustomizationDressSystem — executing an CustomizationOutfitDiffUtils on a real (in-memory) rig.

	Mounts go through the CustomizationPiecePool path with sets the spec builds, so no place art is needed; the
	missing-art path uses an id that has no art anywhere. What these do NOT cover: the place's real art
	(CheckArt / conformance) and how a bound piece renders — that is the Studio checklist.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationClient = ReplicatedStorage.Client.Features.Customization
local CustomizationDressSystem = require(CustomizationClient.Systems.CustomizationDressSystem)
local CustomizationOutfitDiffUtils = require(CustomizationClient.Utils.CustomizationOutfitDiffUtils)
local CustomizationPiecePool = require(CustomizationClient.State.CustomizationPiecePool)
local CustomizationRigOutfitTracker = require(CustomizationClient.State.CustomizationRigOutfitTracker)

return function()
	local container, model, outfit, pool

	local function part(name, parent)
		local p = Instance.new("Part")
		p.Name = name
		p.Color = Color3.fromRGB(100, 100, 100)
		p.Parent = parent
		return p
	end

	local function attachment(name, parent)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = parent
		return a
	end

	-- One Accessory whose Handle carries `socketName`, plus a `Color 1` part.
	local function hairSet(socketName)
		local accessory = Instance.new("Accessory")
		local handle = part("Handle", accessory)
		attachment(socketName or "Hair", handle)
		part("Color 1", accessory)
		return { accessory }
	end

	local function mount(id, extra)
		local m = { category = "hair", id = id, colors = {} }
		for key, value in extra or {} do
			m[key] = value
		end
		return m
	end

	beforeEach(function()
		container = Instance.new("Folder")
		model = Instance.new("Model")
		local head = part("Head", model)
		attachment("Hair", head)
		part("Skin Color", model)
		local mask = part("FacemaskLower", head)
		mask.Transparency = 0.5
		outfit = CustomizationRigOutfitTracker.new(model)
		pool = CustomizationPiecePool.new(container)
	end)

	afterEach(function()
		model:Destroy()
		container:Destroy()
	end)

	describe("mounting", function()
		it("binds a pooled piece to the rig socket of the same name", function()
			local set = hairSet()
			CustomizationPiecePool.release(pool, "Hair10", set)
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "addCosmetic", mountKey = "hair", mount = mount("Hair10") } },
				pool
			)
			local handle = set[1]:FindFirstChild("Handle")
			local constraint = handle:FindFirstChildOfClass("RigidConstraint")
			expect(set[1].Parent).to.equal(model)
			expect(constraint.Attachment1).to.equal(model.Head.Hair)
			expect(handle.Anchored).to.equal(false)
			expect(outfit.mounted.hair.id).to.equal("Hair10")
			expect(model:GetAttribute("CustomizationFailures")).to.equal(nil)
		end)

		it("parks removed pieces back in the pool", function()
			local set = hairSet()
			CustomizationPiecePool.release(pool, "Hair10", set)
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "addCosmetic", mountKey = "hair", mount = mount("Hair10") } },
				pool
			)
			CustomizationDressSystem.apply(outfit, { { kind = "removeCosmetic", mountKey = "hair" } }, pool)
			expect(outfit.mounted.hair).to.equal(nil)
			expect(set[1].Parent).to.equal(container)
			expect(CustomizationPiecePool.take(pool, "Hair10")).to.equal(set)
		end)

		it("falls back to the default when the art is missing, and records why", function()
			CustomizationPiecePool.release(pool, "Hair9", hairSet())
			local before = CustomizationDressSystem.counters()
			CustomizationDressSystem.apply(outfit, {
				{ kind = "addCosmetic", mountKey = "hair", mount = mount("NoSuchHair", { fallbackId = "Hair9" }) },
			}, pool)
			local after = CustomizationDressSystem.counters()
			expect(outfit.mounted.hair.id).to.equal("Hair9")
			expect(after.noArt).to.equal(before.noArt + 1)
			expect(after.fallback).to.equal(before.fallback + 1)
			expect(model:GetAttribute("CustomizationFailures")).to.equal("hair:NoSuchHair:noArt")
		end)

		it("never floats a piece whose socket the rig lacks; the set goes back to the pool", function()
			model.Head.Hair:Destroy()
			outfit = CustomizationRigOutfitTracker.new(model)
			local set = hairSet()
			CustomizationPiecePool.release(pool, "Hair10", set)
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "addCosmetic", mountKey = "hair", mount = mount("Hair10") } },
				pool
			)
			expect(outfit.mounted.hair).to.equal(nil)
			expect(set[1].Parent).to.equal(container)
			expect(outfit.failures.hair).to.equal("Hair10:noSocket")
		end)

		it("refuses a piece whose attachment name does not match", function()
			CustomizationPiecePool.release(pool, "Hair10", hairSet("HairTypo"))
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "addCosmetic", mountKey = "hair", mount = mount("Hair10") } },
				pool
			)
			expect(outfit.mounted.hair).to.equal(nil)
			expect(outfit.failures.hair).to.equal("Hair10:nameMismatch")
		end)

		it("applies the fit offset from the authored placement, never stacked on a reused piece", function()
			local set = hairSet()
			local pieceAttachment = set[1].Handle.Hair
			local authored = pieceAttachment.CFrame
			local offset = CFrame.new(0, 1, 0)
			CustomizationPiecePool.release(pool, "Hair10", set)
			CustomizationDressSystem.apply(outfit, {
				{ kind = "addCosmetic", mountKey = "hair", mount = mount("Hair10", { offset = offset }) },
			}, pool)
			expect(pieceAttachment.CFrame).to.equal(authored * offset:Inverse())
			CustomizationDressSystem.apply(outfit, { { kind = "removeCosmetic", mountKey = "hair" } }, pool)
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "addCosmetic", mountKey = "hair", mount = mount("Hair10") } },
				pool
			)
			expect(pieceAttachment.CFrame).to.equal(authored)
		end)
	end)

	describe("broken sets never reach the pool", function()
		-- Live finding: a rig that fell out of the world lost its Handles but kept the Accessories.
		it("destroys a mounted set whose Handle is gone instead of parking it", function()
			local set = hairSet()
			CustomizationPiecePool.release(pool, "Hair10", set)
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "addCosmetic", mountKey = "hair", mount = mount("Hair10") } },
				pool
			)
			set[1]:FindFirstChild("Handle"):Destroy()
			CustomizationDressSystem.strip(outfit, pool, true)
			expect(set[1].Parent).to.equal(nil)
			expect(CustomizationPiecePool.take(pool, "Hair10")).to.equal(nil)
		end)

		-- Live finding 2: a fallen rig's parts are destroyed a step AFTER they were parked.
		it("skips a broken pooled set: destroys it and falls through to the art", function()
			local set = hairSet()
			CustomizationPiecePool.release(pool, "NoSuchHair", set)
			set[1]:FindFirstChild("Handle"):Destroy()
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "addCosmetic", mountKey = "hair", mount = mount("NoSuchHair") } },
				pool
			)
			-- The broken set is gone, and the art lookup ran (there is none for this id).
			expect(set[1].Parent).to.equal(nil)
			expect(outfit.failures.hair).to.equal("NoSuchHair:noArt")
			expect(CustomizationPiecePool.take(pool, "NoSuchHair")).to.equal(nil)
		end)

		it("takes the next intact set past a broken one", function()
			local broken, good = hairSet(), hairSet()
			CustomizationPiecePool.release(pool, "Hair10", good)
			CustomizationPiecePool.release(pool, "Hair10", broken)
			broken[1]:FindFirstChild("Handle"):Destroy()
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "addCosmetic", mountKey = "hair", mount = mount("Hair10") } },
				pool
			)
			expect(outfit.mounted.hair.pieces).to.equal(good)
		end)

		it("strip without salvage destroys the pieces instead of parking them (a fallen rig)", function()
			local set = hairSet()
			CustomizationPiecePool.release(pool, "Hair10", set)
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "addCosmetic", mountKey = "hair", mount = mount("Hair10") } },
				pool
			)
			CustomizationDressSystem.strip(outfit, pool, false)
			expect(set[1].Parent).to.equal(nil)
			expect(CustomizationPiecePool.take(pool, "Hair10")).to.equal(nil)
			expect(CustomizationRigOutfitTracker.isDressed(outfit)).to.equal(false)
		end)
	end)

	describe("colours and visibility", function()
		it("recolours a mounted piece and restores an absent channel", function()
			local set = hairSet()
			CustomizationPiecePool.release(pool, "Hair10", set)
			local colored = set[1]:FindFirstChild("Color 1")
			CustomizationDressSystem.apply(outfit, {
				{
					kind = "addCosmetic",
					mountKey = "hair",
					mount = mount("Hair10", { colors = { { r = 1, g = 2, b = 3 } } }),
				},
			}, pool)
			expect(colored.Color).to.equal(Color3.fromRGB(1, 2, 3))
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "recolourCosmetic", mountKey = "hair", colors = {} } },
				pool
			)
			expect(colored.Color).to.equal(Color3.fromRGB(100, 100, 100))
		end)

		it("sets a body colour and restores the authored one", function()
			local skin = model:FindFirstChild("Skin Color")
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "setBodyColour", part = "Skin Color", color = { r = 9, g = 9, b = 9 } } },
				pool
			)
			expect(skin.Color).to.equal(Color3.fromRGB(9, 9, 9))
			CustomizationDressSystem.apply(outfit, { { kind = "setBodyColour", part = "Skin Color" } }, pool)
			expect(skin.Color).to.equal(Color3.fromRGB(100, 100, 100))
		end)

		it("hides a head part and restores its authored transparency", function()
			local mask = model.Head.FacemaskLower
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "setHeadPart", part = "FacemaskLower", visible = false } },
				pool
			)
			expect(mask.Transparency).to.equal(1)
			CustomizationDressSystem.apply(outfit, { { kind = "setHeadPart", part = "FacemaskLower" } }, pool)
			expect(mask.Transparency).to.equal(0.5)
		end)
	end)

	describe("strip and nudge", function()
		it("strip parks every piece and leaves the rig undressed", function()
			local set = hairSet()
			CustomizationPiecePool.release(pool, "Hair10", set)
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "addCosmetic", mountKey = "hair", mount = mount("Hair10") } },
				pool
			)
			CustomizationRigOutfitTracker.setWorn(outfit, CustomizationOutfitDiffUtils.empty(), 4)
			CustomizationDressSystem.strip(outfit, pool, true)
			expect(set[1].Parent).to.equal(container)
			expect(CustomizationRigOutfitTracker.isDressed(outfit)).to.equal(false)
		end)

		it("nudgeOffset moves a mounted piece's attachment", function()
			local set = hairSet()
			local pieceAttachment = set[1].Handle.Hair
			local authored = pieceAttachment.CFrame
			CustomizationPiecePool.release(pool, "Hair10", set)
			CustomizationDressSystem.apply(
				outfit,
				{ { kind = "addCosmetic", mountKey = "hair", mount = mount("Hair10") } },
				pool
			)
			local offset = CFrame.new(0.5, 0, 0)
			expect(CustomizationDressSystem.nudgeOffset(model, "Hair10", offset)).to.equal(1)
			expect(pieceAttachment.CFrame).to.equal(authored * offset:Inverse())
			expect(CustomizationDressSystem.nudgeOffset(model, "Hair11", offset)).to.equal(0)
		end)
	end)
end
