local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantFaceUtils = require(script.Parent.OccupantFaceUtils)

return function()
	describe("faceFor", function()
		it("keeps the calm painted smile on patrol and on break", function()
			expect(OccupantFaceUtils.faceFor("patrol")).to.equal("Calm")
			expect(OccupantFaceUtils.faceFor("rest")).to.equal("Calm")
		end)

		it("narrows his pupils while he is noticing something", function()
			expect(OccupantFaceUtils.faceFor("investigate")).to.equal("Noticing")
			expect(OccupantFaceUtils.faceFor("search")).to.equal("Noticing")
		end)

		it("widens his eyes and smile while hunting someone", function()
			expect(OccupantFaceUtils.faceFor("chase")).to.equal("Hunting")
			expect(OccupantFaceUtils.faceFor("catch")).to.equal("Hunting")
		end)

		it("smiles calmly while he works at a desk", function()
			expect(OccupantFaceUtils.faceFor("work", "toDesk", 0)).to.equal("Calm")
			expect(OccupantFaceUtils.faceFor("work", "type", 5)).to.equal("Calm")
		end)

		it("smiles first in the ambush, then notices", function()
			expect(OccupantFaceUtils.faceFor("work", "ambush", 0)).to.equal("Calm")
			expect(OccupantFaceUtils.faceFor("work", "ambush", OccupantConstants.AMBUSH_SMILE)).to.equal("Noticing")
		end)

		it("tips his head down calm, then hunts at the bottom", function()
			expect(OccupantFaceUtils.faceFor("work", "tip", 0)).to.equal("Calm")
			expect(OccupantFaceUtils.faceFor("work", "tip", OccupantConstants.TIP_CALM)).to.equal("Hunting")
			expect(OccupantFaceUtils.faceFor("work", "tipHold", 0)).to.equal("Hunting")
			expect(OccupantFaceUtils.faceFor("work", "tipBack", 0)).to.equal("Calm")
		end)

		it("notices while he stares and hunts when he bends to look", function()
			expect(OccupantFaceUtils.faceFor("stare", "hold", 3)).to.equal("Noticing")
			expect(OccupantFaceUtils.faceFor("stare", "check", 0)).to.equal("Hunting")
			expect(OccupantFaceUtils.faceFor("stare", "open", 0)).to.equal("Hunting")
		end)

		it("only ever names a face the template ships", function()
			for _, mode in { "patrol", "investigate", "chase", "search", "rest", "catch", "work", "stare" } do
				expect(table.find(OccupantAssets.FACES, OccupantFaceUtils.faceFor(mode))).to.be.ok()
			end
		end)
	end)
end
