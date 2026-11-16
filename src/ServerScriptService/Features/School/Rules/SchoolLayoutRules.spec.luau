local ServerScriptService = game:GetService("ServerScriptService")

local SchoolLayoutRules = require(script.Parent.SchoolLayoutRules)
local Gen = require(ServerScriptService.Features.School.Utils.SchoolLayoutGenerationUtils)
local Base = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants).LAYOUT

return function()
	describe("problem", function()
		it("finds nothing wrong with a generated School", function()
			for seed = 1, 3 do
				expect(SchoolLayoutRules.problem(Gen.generate(Base, seed))).to.equal(nil)
			end
		end)

		it("refuses a School without its lounge", function()
			local layout = Gen.generate(Base, 1)
			for _, room in layout.rooms do
				if room.roomType == "lounge" then
					room.roomType = "storage"
				end
			end
			local reason = SchoolLayoutRules.problem(layout)
			expect(reason ~= nil and string.find(reason, "0 lounges", 1, true) ~= nil).to.equal(true)
		end)

		it("refuses a School with too few classrooms", function()
			local layout = Gen.generate(Base, 1)
			for _, room in layout.rooms do
				room.kit = nil
			end
			expect(SchoolLayoutRules.problem(layout)).to.equal("0 classrooms (wanted 6)")
		end)
	end)
end
