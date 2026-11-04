local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalloutAssets = require(script.Parent.CalloutAssets)
local CalloutRegistry = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutRegistry)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)

return function()
	it("has an icon for every ping", function()
		for _, ping in CalloutRegistry.pings() do
			expect(CalloutAssets.PING_ICON[ping.id]).to.be.ok()
			expect(CalloutAssets.pingImage(ping.id) ~= "").to.equal(true)
		end
	end)

	it("has a picture for every sticker", function()
		for _, item in CosmeticRegistry.ofKind("sticker") do
			expect(CalloutAssets.stickerImage(item.id) ~= "").to.equal(true)
		end
	end)

	it("draws every sticker with its own uploaded art", function()
		for _, item in CosmeticRegistry.ofKind("sticker") do
			local image = UIAssets.stickers[item.id]
			expect(image).to.be.ok()
			expect(string.match(image, "^rbxassetid://%d+$")).to.be.ok()
			expect(CalloutAssets.stickerImage(item.id)).to.equal(image)
		end
	end)

	it("has no uploaded art for a sticker the registry doesn't know", function()
		for id in UIAssets.stickers do
			local item = CosmeticRegistry.get(id)
			expect(item).to.be.ok()
			expect(item.kind).to.equal("sticker")
		end
	end)
end
