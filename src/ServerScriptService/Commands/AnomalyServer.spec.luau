--[[
	Unit tests for the anomaly Cmdr command. Mock strategy (the OccupantTurnServer.spec convention): patch the
	OfficeServiceServer method the command calls, so the live office is never touched.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local anomaly = require(ServerScriptService.Commands.AnomalyServer)

return function()
	describe("AnomalyServer", function()
		local original
		local built = true
		local asked = "untouched"

		beforeAll(function()
			original = OfficeServiceServer.forceAnomalies
			OfficeServiceServer.forceAnomalies = function(_self, ids)
				asked = ids
				return built
			end
		end)

		afterAll(function()
			OfficeServiceServer.forceAnomalies = original
		end)

		beforeEach(function()
			asked = "untouched"
			built = true
		end)

		it("forces exactly the named anomaly", function()
			local message = anomaly({ Executor = {} }, "WetFloor")
			expect(#asked).to.equal(1)
			expect(asked[1]).to.equal("wetFloor")
			expect(message:find("wetFloor")).to.be.ok()
		end)

		it("clears with none", function()
			anomaly({ Executor = {} }, "none")
			expect(#asked).to.equal(0)
		end)

		it("restores the seed's pick with reroll", function()
			anomaly({ Executor = {} }, "reroll")
			expect(asked).to.equal(nil)
		end)

		it("refuses an unknown id without touching the office", function()
			local message = anomaly({ Executor = {} }, "ghost")
			expect(asked).to.equal("untouched")
			expect(message:find("Unknown")).to.be.ok()
		end)

		it("reports when no office stands", function()
			built = false
			local message = anomaly({ Executor = {} }, "banner")
			expect(message:find("Nothing changed")).to.be.ok()
		end)
	end)
end
