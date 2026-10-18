local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationOccupantRegistry = require(script.Parent.AnimationOccupantRegistry)
local AnimationRegistry = require(script.Parent.AnimationRegistry)
local AnimationTypes = require(script.Parent.AnimationTypes)
local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)

return function()
	it("holds only uploaded slots, with canonical ids", function()
		for id, def in AnimationOccupantRegistry do
			local slot = OccupantAssets.ANIMATIONS[id]
			expect(slot).to.be.ok()
			expect(slot.assetId).never.to.equal(OccupantAssets.PENDING)
			expect(AnimationTypes.isCanonicalAssetId(def.assetId)).to.equal(true)
		end
	end)

	it("leaves every pending slot out of the registry", function()
		for id, slot in OccupantAssets.ANIMATIONS do
			if slot.assetId == OccupantAssets.PENDING then
				expect(AnimationRegistry.get(id)).to.equal(nil)
			end
		end
	end)

	it("is composed as the occupant domain", function()
		expect(AnimationRegistry.domain("occupant")).to.equal(AnimationOccupantRegistry)
	end)
end
