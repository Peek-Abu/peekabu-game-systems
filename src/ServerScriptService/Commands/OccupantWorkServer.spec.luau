--[[
	Unit tests for the occupantwork Cmdr command. Mock strategy (the RoundStartServer.spec convention): patch the
	OccupantServiceServer method the command calls, so the live Manager is never touched.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local OccupantServiceServer = require(ServerScriptService.Features.Occupant.OccupantServiceServer)
local occupantWork = require(ServerScriptService.Commands.OccupantWorkServer)

return function()
	describe("OccupantWorkServer", function()
		local original
		local answer = { true, "desk d4" }
		local asked = nil

		beforeAll(function()
			original = OccupantServiceServer.summonToDesk
			OccupantServiceServer.summonToDesk = function(_self, player)
				asked = player
				return answer[1], answer[2]
			end
		end)

		afterAll(function()
			OccupantServiceServer.summonToDesk = original
		end)

		it("sends him for the caller and says where", function()
			local caller = { Name = "dev" }
			local message = occupantWork({ Executor = caller })
			expect(asked).to.equal(caller)
			expect(message:find("desk d4")).to.be.ok()
		end)

		it("reports why nothing was sent", function()
			answer = { false, "no shift is running" }
			local message = occupantWork({ Executor = {} })
			expect(message:find("Nothing sent: no shift is running")).to.be.ok()
		end)
	end)
end
