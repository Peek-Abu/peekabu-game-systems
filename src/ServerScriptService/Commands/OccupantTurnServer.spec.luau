--[[
	Unit tests for the occupantturn Cmdr command. Mock strategy (the OccupantWorkServer.spec convention): patch the
	OccupantServiceServer method the command calls, so the live Manager is never touched.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local OccupantServiceServer = require(ServerScriptService.Features.Occupant.OccupantServiceServer)
local occupantTurn = require(ServerScriptService.Commands.OccupantTurnServer)

return function()
	describe("OccupantTurnServer", function()
		local original
		local answer = { true, "queued" }
		local asked = nil

		beforeAll(function()
			original = OccupantServiceServer.forceTurn
			OccupantServiceServer.forceTurn = function(_self, player, kind)
				asked = { player = player, kind = kind }
				return answer[1], answer[2]
			end
		end)

		afterAll(function()
			OccupantServiceServer.forceTurn = original
		end)

		it("forces the named variant for the caller", function()
			local caller = { Name = "dev" }
			local message = occupantTurn({ Executor = caller }, "stare")
			expect(asked.player).to.equal(caller)
			expect(asked.kind).to.equal("stare")
			expect(message:find("stare")).to.be.ok()
		end)

		it("takes auto to clear a forced variant", function()
			occupantTurn({ Executor = {} }, "auto")
			expect(asked.kind).to.equal("auto")
		end)

		it("refuses an unknown variant without asking the service", function()
			asked = nil
			local message = occupantTurn({ Executor = {} }, "spin")
			expect(asked).to.equal(nil)
			expect(message:find("Unknown")).to.be.ok()
		end)

		it("reports why nothing was forced", function()
			answer = { false, "no shift is running" }
			local message = occupantTurn({ Executor = {} }, "knowing")
			expect(message:find("Nothing forced: no shift is running")).to.be.ok()
		end)
	end)
end
