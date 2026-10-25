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
end
