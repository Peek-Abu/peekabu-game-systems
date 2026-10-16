local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumAssets = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumAssets)
local VacuumSkinRegistry = require(script.Parent.VacuumSkinRegistry)

return function()
	describe("skins", function()
		it("has Standard Issue as the default, on the standard template and hose", function()
			local skin = VacuumSkinRegistry.get(VacuumSkinRegistry.DEFAULT)
			expect(skin).to.be.ok()
			expect(skin.name).to.equal("StandardIssue")
			expect(skin.template).to.equal("Vacuum")
			expect(skin.hoseTexture).to.equal(VacuumAssets.HOSE_TEXTURE)
		end)

		it("has Brass Bellows (Rare) on its own template and the copper hose", function()
			local skin = VacuumSkinRegistry.get("BrassBellows")
			expect(skin).to.be.ok()
			expect(skin.displayName).to.equal("Brass Bellows")
			expect(skin.rarity).to.equal("Rare")
			expect(skin.template).to.equal("VacuumBrassBellows")
			expect(skin.hoseTexture).to.equal(VacuumAssets.HOSE_TEXTURE_COPPER)
		end)

		it("names every skin by its key", function()
			for name, skin in VacuumSkinRegistry.SKINS do
				expect(skin.name).to.equal(name)
			end
		end)

		it("has no skin for an unknown name", function()
			expect(VacuumSkinRegistry.get("Nope")).never.to.be.ok()
		end)
	end)

	describe("skinFor", function()
		it("gives the owner (icemonkey1) Brass Bellows", function()
			expect(VacuumSkinRegistry.skinFor(20661908)).to.equal("BrassBellows")
		end)

		it("gives everyone else nothing (Standard Issue)", function()
			expect(VacuumSkinRegistry.skinFor(1)).never.to.be.ok()
			expect(VacuumSkinRegistry.skinFor(-1)).never.to.be.ok()
		end)
	end)
end
