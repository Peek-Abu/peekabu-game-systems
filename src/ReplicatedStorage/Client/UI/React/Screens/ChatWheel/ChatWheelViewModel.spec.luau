local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)
local VM = require(script.Parent.ChatWheelViewModel)

return function()
	local function owns(ids)
		local set = {}
		for _, id in ids do
			set[id] = true
		end
		return function(id)
			return set[id] == true
		end
	end

	it("shows the six pings and the 4 sticker slots, owned stickers with their picture", function()
		local loadout = CosmeticConstants.defaultLoadout()
		loadout.stickers = { "CozyPack.CocoaBreak", "", "BubblePack.Yay", "" }
		local view = VM.view(loadout, owns({ "CozyPack.CocoaBreak" }))
		expect(#view.pings).to.equal(6)
		expect(view.pings[1].word).to.equal("Gloom here")
		expect(view.stickers[1].name).to.equal("Cocoa Break")
		expect(view.stickers[1].image).to.be.ok()
		expect(view.stickers[2].empty).to.equal(true)
		-- In a slot but not owned (any more): shown empty.
		expect(view.stickers[3].empty).to.equal(true)
	end)

	it("puts the first ping at the top and the sticker slots at the corners, top-left first", function()
		local top = VM.pingPosition(1, 6, 100)
		expect(math.abs(top.X) < 0.001 and math.abs(top.Y + 100) < 0.001).to.equal(true)
		expect(VM.stickerPosition(1, 50)).to.equal(Vector2.new(-50, -50))
		expect(VM.stickerPosition(3, 50)).to.equal(Vector2.new(50, 50))
	end)

	it("picks a ping near the middle, a sticker slot beyond, nothing at the centre", function()
		local view = VM.view(CosmeticConstants.defaultLoadout(), owns({}))
		local up = VM.pick(Vector2.new(0, -60), view.pings, 20, 120)
		expect(up.kind).to.equal("ping")
		expect(up.id).to.equal("gloom")
		local corner = VM.pick(Vector2.new(150, 150), view.pings, 20, 120)
		expect(corner.kind).to.equal("sticker")
		expect(corner.slot).to.equal(3)
		expect(VM.pick(Vector2.new(-150, -140), view.pings, 20, 120).slot).to.equal(1)
		expect(VM.pick(Vector2.new(3, 3), view.pings, 20, 120)).never.to.be.ok()
	end)
end
