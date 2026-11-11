local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantKindRegistry = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantKindRegistry)
local OccupantPortraitAssets = require(script.Parent.OccupantPortraitAssets)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)

return function()
	it("keeps Harlow's portraits as they were", function()
		expect(OccupantPortraitAssets.portrait("harlow", "calm")).to.equal("managerCalm")
		expect(OccupantPortraitAssets.portrait("harlow", "hunt")).to.equal("managerHunt")
	end)

	it("names a slot for every kind, each mood", function()
		for _, kind in OccupantKindRegistry.ids() do
			for _, mood in { "calm", "hunt" } do
				local slot = OccupantPortraitAssets.slot(kind, mood)
				expect(slot).to.be.ok()
				-- A slot is a kit icon: filled with an uploaded id, or PENDING "".
				local image = UIAssets.toonIcons[slot]
				expect(type(image)).to.equal("string")
				expect(image == "" or string.match(image, "^rbxassetid://%d+$") ~= nil).to.equal(true)
			end
		end
	end)

	it("gives Bramble its own slots, never Harlow's", function()
		expect(OccupantPortraitAssets.slot("bramble", "calm")).to.equal("brambleCalm")
		expect(OccupantPortraitAssets.slot("bramble", "hunt")).to.equal("brambleHunt")
		for _, mood in { "calm", "hunt" } do
			local icon = OccupantPortraitAssets.portrait("bramble", mood)
			expect(icon).never.to.equal("managerCalm")
			expect(icon).never.to.equal("managerHunt")
		end
	end)

	it("shows the neutral stand-in for a kind whose slot is still empty", function()
		for _, mood in { "calm", "hunt" } do
			local slot = OccupantPortraitAssets.slot("bramble", mood)
			local expected = if UIAssets.toonIcons[slot] == "" then OccupantPortraitAssets.NEUTRAL else slot
			expect(OccupantPortraitAssets.portrait("bramble", mood)).to.equal(expected)
		end
	end)

	it("uses a real, filled, monster-neutral icon as the stand-in", function()
		local neutral = OccupantPortraitAssets.NEUTRAL
		expect(string.match(UIAssets.toonIcons[neutral], "^rbxassetid://%d+$") ~= nil).to.equal(true)
		expect(neutral).never.to.equal("managerCalm")
		expect(neutral).never.to.equal("managerHunt")
		expect(neutral).never.to.equal("gloom")
	end)

	it("shows the stand-in for an unknown kind", function()
		expect(OccupantPortraitAssets.slot("ghost", "calm")).to.equal(nil)
		expect(OccupantPortraitAssets.portrait("ghost", "calm")).to.equal(OccupantPortraitAssets.NEUTRAL)
	end)
end
