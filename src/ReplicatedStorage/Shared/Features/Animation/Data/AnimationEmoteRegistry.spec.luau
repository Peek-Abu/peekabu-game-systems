local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.AnimationEmoteRegistry)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)

return function()
	it("keys every clip to an emote in the catalogue, as a protected full-body replicated action", function()
		for key, def in Registry do
			local id = string.match(key, "^emote:(.+)$")
			expect(id).to.be.ok()
			local item = CosmeticRegistry.get(id)
			expect(item).to.be.ok()
			expect(item.kind).to.equal("emote")
			expect(def.replicable).to.equal(true)
			expect(def.layer).to.equal("full")
			expect(def.interruption).to.equal("protected")
		end
	end)

	it("gives every employee's free emote a clip", function()
		for _, id in { "Pippa.Wave", "Cappy.FistBump", "Prickles.Huff" } do
			expect(CosmeticRegistry.get(id).source).to.equal("default")
			expect(Registry["emote:" .. id]).to.be.ok()
			expect(Registry["emote:" .. id].looped).to.equal(false)
		end
	end)

	it("gives every clip its own wire id, and plays PJ Cappy's Cocoa Sip", function()
		local seen = {}
		for _, def in Registry do
			expect(seen[def.wireId]).to.equal(nil)
			seen[def.wireId] = true
		end
		expect(Registry["emote:Cappy.CocoaSip"]).to.be.ok()
		expect(Registry["emote:Cappy.CocoaSip"].looped).to.equal(false)
	end)
end
