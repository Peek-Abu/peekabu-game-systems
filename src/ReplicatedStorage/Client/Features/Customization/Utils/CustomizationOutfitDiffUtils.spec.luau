--!strict
--[=[
	Unit tests for CustomizationOutfitDiffUtils — the pure target/diff step of dressing a rig. No Instances.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationOutfitDiffUtils =
	require(ReplicatedStorage.Client.Features.Customization.Utils.CustomizationOutfitDiffUtils)

return function()
	local function rgb(r, g, b)
		return { source = "rgb", r = r, g = g, b = b }
	end

	local function appearance()
		return { cosmetics = {}, accessories = {}, body = {}, headType = "Uncovered", surfaces = {} }
	end

	local function kinds(ops)
		local out = {}
		for _, op in ops do
			table.insert(out, `{op.kind}:{op.mountKey or op.part or op.channelKey}`)
		end
		return table.concat(out, ",")
	end

	local function find(ops, kind, key)
		for _, op in ops do
			if op.kind == kind and (op.mountKey == key or op.part == key or op.channelKey == key) then
				return op
			end
		end
		return nil
	end

	describe("target", function()
		it("keys single-selection mounts by category and accessories by position", function()
			local look = appearance()
			look.cosmetics.hair = { id = "Hair10", colors = {} }
			look.accessories = { { id = "FishingHat", colors = {} }, { id = "PaperboyHat", colors = {} } }
			local outfit = CustomizationOutfitDiffUtils.target(look)
			expect(outfit.mounts.hair.id).to.equal("Hair10")
			expect(outfit.mounts["accessory:1"].id).to.equal("FishingHat")
			expect(outfit.mounts["accessory:2"].id).to.equal("PaperboyHat")
			expect(table.concat(outfit.mountOrder, ",")).to.equal("hair,accessory:1,accessory:2")
		end)

		it("records the head type's default as the fallback, but not when it is the same id", function()
			local look = appearance()
			look.cosmetics.hair = { id = "Hair10", colors = {} }
			look.cosmetics.eyebrows = { id = "Eyebrows4", colors = {} }
			local outfit = CustomizationOutfitDiffUtils.target(look)
			expect(outfit.mounts.hair.fallbackId).to.equal("Hair9")
			expect(outfit.mounts.eyebrows.fallbackId).to.equal(nil)
		end)

		it("drops a retired id (the plan skips it)", function()
			local look = appearance()
			look.cosmetics.hair = { id = "HairRetired", colors = {} }
			expect(CustomizationOutfitDiffUtils.target(look).mounts.hair).to.equal(nil)
		end)

		it("keeps only surfaces that set something", function()
			local look = appearance()
			look.surfaces.backpack1 = { pattern = "Pattern1" }
			local outfit = CustomizationOutfitDiffUtils.target(look)
			expect(outfit.surfaces.backpack1.pattern).to.equal("Pattern1")
			expect(outfit.surfaces.clothing1).to.equal(nil)
		end)

		it("resolves body colours and head-type visibility", function()
			local look = appearance()
			look.body.skin = rgb(1, 2, 3)
			local outfit = CustomizationOutfitDiffUtils.target(look)
			expect(outfit.bodyColors["Skin Color"].g).to.equal(2)
			expect(outfit.headParts["Skin Color-Uncovered"]).to.equal(true)
			expect(outfit.headParts["Skin Color-Covered"]).to.equal(false)
		end)
	end)

	describe("compute", function()
		it("returns nothing for equal outfits", function()
			local look = appearance()
			look.cosmetics.hair = { id = "Hair10", colors = { rgb(5, 5, 5) } }
			look.body.skin = rgb(1, 2, 3)
			expect(
				#CustomizationOutfitDiffUtils.compute(
					CustomizationOutfitDiffUtils.target(look),
					CustomizationOutfitDiffUtils.target(look)
				)
			).to.equal(0)
		end)

		it("dresses a fresh rig with adds, colours and head parts", function()
			local look = appearance()
			look.cosmetics.hair = { id = "Hair10", colors = {} }
			look.body.skin = rgb(1, 2, 3)
			local ops = CustomizationOutfitDiffUtils.compute(
				CustomizationOutfitDiffUtils.empty(),
				CustomizationOutfitDiffUtils.target(look)
			)
			expect(find(ops, "addCosmetic", "hair").mount.id).to.equal("Hair10")
			expect(find(ops, "setBodyColour", "Skin Color").color.r).to.equal(1)
			expect(find(ops, "setHeadPart", "Skin Color-Covered").visible).to.equal(false)
			expect(find(ops, "removeCosmetic", "hair")).to.equal(nil)
		end)

		it("replaces a changed id: remove before add", function()
			local from = appearance()
			from.cosmetics.hair = { id = "Hair10", colors = {} }
			local to = appearance()
			to.cosmetics.hair = { id = "Hair11", colors = {} }
			local ops = CustomizationOutfitDiffUtils.compute(
				CustomizationOutfitDiffUtils.target(from),
				CustomizationOutfitDiffUtils.target(to)
			)
			expect(kinds(ops)).to.equal("removeCosmetic:hair,addCosmetic:hair")
		end)

		it("recolours in place when only colours change", function()
			local from = appearance()
			from.cosmetics.hair = { id = "Hair10", colors = { rgb(1, 1, 1) } }
			local to = appearance()
			to.cosmetics.hair = { id = "Hair10", colors = { rgb(2, 2, 2) } }
			local ops = CustomizationOutfitDiffUtils.compute(
				CustomizationOutfitDiffUtils.target(from),
				CustomizationOutfitDiffUtils.target(to)
			)
			expect(kinds(ops)).to.equal("recolourCosmetic:hair")
			expect(ops[1].colors[1].r).to.equal(2)
		end)

		it("removes a mount the target no longer has", function()
			local from = appearance()
			from.accessories = { { id = "FishingHat", colors = {} } }
			local ops = CustomizationOutfitDiffUtils.compute(
				CustomizationOutfitDiffUtils.target(from),
				CustomizationOutfitDiffUtils.target(appearance())
			)
			expect(kinds(ops)).to.equal("removeCosmetic:accessory:1")
		end)

		-- A pooled rig handed to a new owner: the old owner's colour must go back to the rig's own.
		it("restores the authored body colour the target does not set", function()
			local from = appearance()
			from.body.skin = rgb(9, 9, 9)
			local ops = CustomizationOutfitDiffUtils.compute(
				CustomizationOutfitDiffUtils.target(from),
				CustomizationOutfitDiffUtils.target(appearance())
			)
			local op = find(ops, "setBodyColour", "Skin Color")
			expect(op).to.be.ok()
			expect(op.color).to.equal(nil)
		end)

		it("restores the authored surface when a channel is cleared", function()
			local from = appearance()
			from.surfaces.backpack1 = { pattern = "Pattern1" }
			local ops = CustomizationOutfitDiffUtils.compute(
				CustomizationOutfitDiffUtils.target(from),
				CustomizationOutfitDiffUtils.target(appearance())
			)
			local op = find(ops, "setSurface", "backpack1")
			expect(op.surface.pattern).to.equal(nil)
			expect(op.surface.texture).to.equal(nil)
		end)

		it("emits a head-type switch as visibility flips", function()
			local from = appearance()
			local to = appearance()
			to.headType = "Covered"
			local ops = CustomizationOutfitDiffUtils.compute(
				CustomizationOutfitDiffUtils.target(from),
				CustomizationOutfitDiffUtils.target(to)
			)
			expect(find(ops, "setHeadPart", "Skin Color-Covered").visible).to.equal(true)
			expect(find(ops, "setHeadPart", "Skin Color-Uncovered").visible).to.equal(false)
		end)

		it("is deterministic", function()
			local from = appearance()
			from.accessories = { { id = "FishingHat", colors = {} } }
			from.body.skin = rgb(1, 1, 1)
			local to = appearance()
			to.cosmetics.hair = { id = "Hair10", colors = {} }
			to.headType = "Covered"
			local first = kinds(
				CustomizationOutfitDiffUtils.compute(
					CustomizationOutfitDiffUtils.target(from),
					CustomizationOutfitDiffUtils.target(to)
				)
			)
			for _ = 1, 5 do
				expect(
					kinds(
						CustomizationOutfitDiffUtils.compute(
							CustomizationOutfitDiffUtils.target(from),
							CustomizationOutfitDiffUtils.target(to)
						)
					)
				).to.equal(first)
			end
		end)
	end)
end
