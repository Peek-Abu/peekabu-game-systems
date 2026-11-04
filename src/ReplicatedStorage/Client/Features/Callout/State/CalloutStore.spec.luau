local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalloutStore = require(script.Parent.CalloutStore)
local CalloutConstants = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutConstants)

return function()
	afterEach(function()
		CalloutStore.reset()
	end)

	it("keeps each player's latest sticker while it is fresh", function()
		CalloutStore.sticker(1, "CozyPack.CocoaBreak", 10)
		CalloutStore.sticker(1, "CozyPack.Sleepy", 11)
		local all = CalloutStore.stickers()
		expect(CalloutStore.fresh(all, 1, 11.5)).to.equal("CozyPack.Sleepy")
		expect(CalloutStore.fresh(all, 1, 11 + CalloutConstants.STICKER_SECONDS + 0.1)).never.to.be.ok()
		expect(CalloutStore.fresh(all, 2, 11)).never.to.be.ok()
	end)

	it("expires a sticker only if no newer one came", function()
		CalloutStore.sticker(5, "CozyPack.CocoaBreak", 1)
		CalloutStore.sticker(5, "CozyPack.Sleepy", 2)
		CalloutStore.expire(5, 1)
		expect(CalloutStore.stickers()[5].id).to.equal("CozyPack.Sleepy")
		CalloutStore.expire(5, 2)
		expect(CalloutStore.stickers()[5]).never.to.be.ok()
	end)

	it("forgets a player who left", function()
		CalloutStore.sticker(3, "CozyPack.CocoaBreak", 1)
		CalloutStore.forget(3)
		expect(CalloutStore.stickers()[3]).never.to.be.ok()
	end)
end
