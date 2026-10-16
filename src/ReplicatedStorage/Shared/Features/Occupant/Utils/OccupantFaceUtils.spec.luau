local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
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

		it("only ever names a face the template ships", function()
			for _, mode in { "patrol", "investigate", "chase", "search", "rest", "catch" } do
				expect(table.find(OccupantAssets.FACES, OccupantFaceUtils.faceFor(mode))).to.be.ok()
			end
		end)
	end)
end
