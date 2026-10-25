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
end
