local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PaperTextureViewModel = require(script.Parent.PaperTextureViewModel)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local COLOR = UIPaperConstants.COLOR

local function slots(id)
	return {
		cork = { id = id, tile = Vector2.new(192, 192) },
		wood = { id = id, tile = Vector2.new(256, 128) },
	}
end

return function()
	describe("materialOf", function()
		it("names the material of each paper colour", function()
			expect(PaperTextureViewModel.materialOf(COLOR.cream)).to.equal("cream")
			expect(PaperTextureViewModel.materialOf(COLOR.manila)).to.equal("manila")
			expect(PaperTextureViewModel.materialOf(COLOR.manilaDeep)).to.equal("manilaDeep")
			expect(PaperTextureViewModel.materialOf(COLOR.sticky)).to.equal("sticky")
			expect(PaperTextureViewModel.materialOf(COLOR.cork)).to.equal("cork")
			expect(PaperTextureViewModel.materialOf(COLOR.wood)).to.equal("wood")
		end)

		it("matches a colour built separately from the same hex", function()
			expect(PaperTextureViewModel.materialOf(Color3.fromHex("E8C98A"))).to.equal("manila")
			expect(PaperTextureViewModel.materialOf(Color3.fromHex("f4ecd6"))).to.equal("cream")
		end)

		it("has no material for a colour that is not paper", function()
			expect(PaperTextureViewModel.materialOf(COLOR.office)).to.equal(nil)
			expect(PaperTextureViewModel.materialOf(COLOR.stamp)).to.equal(nil)
			expect(PaperTextureViewModel.materialOf(COLOR.ink)).to.equal(nil)
		end)
	end)

	describe("layer", function()
		it("draws no layer while the slot is PENDING", function()
			expect(PaperTextureViewModel.layer("cork", slots(""))).to.equal(nil)
		end)

		it("tiles an uploaded texture at its file size", function()
			local layer = PaperTextureViewModel.layer("wood", slots("rbxassetid://1"))
			expect(layer.image).to.equal("rbxassetid://1")
			expect(layer.tile).to.equal(Vector2.new(256, 128))
		end)

		it("draws nothing for no material or a missing slot", function()
			expect(PaperTextureViewModel.layer(nil, slots("rbxassetid://1"))).to.equal(nil)
			expect(PaperTextureViewModel.layer("sticky", slots("rbxassetid://1"))).to.equal(nil)
		end)
	end)

	describe("the game's slots", function()
		it("lists the six textures at their file sizes", function()
			local sizes = {
				cream = Vector2.new(160, 160),
				manila = Vector2.new(160, 160),
				manilaDeep = Vector2.new(128, 128),
				sticky = Vector2.new(128, 128),
				cork = Vector2.new(192, 192),
				wood = Vector2.new(256, 128),
			}
			local count = 0
			for material, size in sizes do
				local slot = UIAssets.paper[material]
				expect(slot ~= nil).to.equal(true)
				expect(slot.tile).to.equal(size)
				count += 1
			end
			for _ in UIAssets.paper do
				count -= 1
			end
			expect(count).to.equal(0)
		end)

		it("holds only PENDING or well-formed asset ids", function()
			for _, slot in UIAssets.paper do
				expect(PaperTextureViewModel.validId(slot.id)).to.equal(true)
			end
			expect(PaperTextureViewModel.validId("")).to.equal(true)
			expect(PaperTextureViewModel.validId("rbxassetid://123")).to.equal(true)
			expect(PaperTextureViewModel.validId("123")).to.equal(false)
			expect(PaperTextureViewModel.validId("rbxassetid://abc")).to.equal(false)
			expect(PaperTextureViewModel.validId("rbxassetid://")).to.equal(false)
		end)
	end)
end
