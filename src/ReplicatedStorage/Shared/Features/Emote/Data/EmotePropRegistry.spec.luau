local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.EmotePropRegistry)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)

return function()
	it("keys every entry to a registered animation", function()
		for key in Registry.entries do
			expect(AnimationRegistry.get(key)).to.be.ok()
		end
	end)

	it("brings out PJ Cappy's pillow and cocoa mug in his showcase idle", function()
		expect(table.find(Registry.get("cappypjidle").props, "Pillow")).to.be.ok()
		expect(table.find(Registry.get("cappypjidle").props, "Cocoa")).to.be.ok()
	end)

	it("brings out only the cocoa mug in Cocoa Sip, no pillow", function()
		local props = Registry.get("emote:Cappy.CocoaSip").props
		expect(table.find(props, "Cocoa")).to.be.ok()
		expect(table.find(props, "Pillow")).never.to.be.ok()
	end)

	it("lists unique, non-empty prop names", function()
		for _, entry in Registry.entries do
			expect(#entry.props > 0).to.equal(true)
			local seen = {}
			for _, prop in entry.props do
				expect(type(prop)).to.equal("string")
				expect(#prop > 0).to.equal(true)
				expect(seen[prop]).to.equal(nil)
				seen[prop] = true
			end
		end
	end)

	it("never lists a swap prop among the window props", function()
		for _, entry in Registry.entries do
			for _, prop in entry.swaps or {} do
				expect(table.find(entry.props, prop)).never.to.be.ok()
			end
		end
		expect(table.find(Registry.get("emote:Prickles.Lasso").swaps, "LassoLoop")).to.be.ok()
	end)

	it("names an emote in the catalogue for every emote key", function()
		for key in Registry.entries do
			local id = string.match(key, "^emote:(.+)$")
			if id ~= nil then
				local item = CosmeticRegistry.get(id)
				expect(item).to.be.ok()
				expect(item.kind).to.equal("emote")
			end
		end
	end)

	it("carries the Bubble Ride and Big Roundup emotes' props", function()
		expect(Registry.get("emote:Pippa.Bubbles")).to.be.ok()
		expect(table.find(Registry.get("emote:Pippa.Bubbles").props, "BubbleWand")).to.be.ok()
		-- Bubble Ride: the duck ring stays worn at her waist (a holster prop), so the clip never brings it out.
		expect(table.find(Registry.get("emote:Pippa.Bubbles").props, "DuckRing")).never.to.be.ok()
		expect(table.find(Registry.get("emote:Prickles.Lasso").props, "HoseLasso")).to.be.ok()
		expect(Registry.get("emote:Nobody.Nothing")).to.equal(nil)
	end)

	it("brings out each Legendary skin's props in its unlock reveal", function()
		local pippa = Registry.get("pippabubblebuddyreveal")
		expect(table.find(pippa.props, "BubbleWand")).to.be.ok()
		expect(table.find(pippa.props, "DuckRing")).to.be.ok()
		expect(table.find(Registry.get("pricklessheriffreveal").props, "HoseLasso")).to.be.ok()
		expect(table.find(Registry.get("cappypjreveal").props, "Pillow")).to.be.ok()
		expect(table.find(Registry.get("cappypjreveal").props, "Cocoa")).to.be.ok()
	end)

	it("brings out Cappy's phone in his hire reveal", function()
		expect(table.find(Registry.get("cappyhirereveal").props, "Phone")).to.be.ok()
	end)

	it("holds Sheriff Prickles' coil out in his showcase idle", function()
		expect(table.find(Registry.get("pricklessheriffidle").props, "HoseLasso")).to.be.ok()
	end)

	it("marks the showcase idles: their props show while standing idle, in menus and in a shift", function()
		for _, key in { "pricklessheriffidle", "cappypjidle" } do
			expect(Registry.get(key).idle).to.equal(true)
		end
		expect(Registry.get("emote:Prickles.Lasso").idle).never.to.be.ok()
	end)

	it(
		"leaves a skin's fidget out: it plays over the idle, which keeps the props (a prop track would take them over)",
		function()
			expect(Registry.get("pricklessherifffidget")).to.equal(nil)
		end
	)

	it("finds an entry's key from its clip's asset id, and nothing for other clips", function()
		for key in Registry.entries do
			expect(Registry.keyForAsset(AnimationRegistry.get(key).assetId)).to.equal(key)
		end
		expect(Registry.keyForAsset("rbxassetid://1")).to.equal(nil)
		expect(Registry.keyForAsset("")).to.equal(nil)
	end)
end
