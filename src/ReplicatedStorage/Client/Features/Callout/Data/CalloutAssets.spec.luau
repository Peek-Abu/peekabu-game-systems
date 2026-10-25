local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalloutAssets = require(script.Parent.CalloutAssets)
local CalloutRegistry = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutRegistry)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)

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
end
