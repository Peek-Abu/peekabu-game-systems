local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumSkinRegistry = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumSkinRegistry)
local VacuumSkinRules = require(script.Parent.VacuumSkinRules)

return function()
	describe("select", function()
		it("gives the wanted skin when it exists", function()
			expect(VacuumSkinRules.select("BrassBellows").name).to.equal("BrassBellows")
		end)

		it("falls back to Standard Issue for none or an unknown name", function()
			expect(VacuumSkinRules.select(nil).name).to.equal(VacuumSkinRegistry.DEFAULT)
			expect(VacuumSkinRules.select("Nope").name).to.equal(VacuumSkinRegistry.DEFAULT)
		end)
	end)

	describe("forPlayer", function()
		it("puts the owner in Brass Bellows and everyone else in Standard Issue", function()
			expect(VacuumSkinRules.forPlayer(20661908).name).to.equal("BrassBellows")
			expect(VacuumSkinRules.forPlayer(1).name).to.equal("StandardIssue")
		end)
	end)
end
