--[[
	Unit tests for the harlow Cmdr command. Mock strategy (the OccupantWorkServer.spec convention): patch the
	OccupantServiceServer method the command calls, so the live Manager is never touched.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local OccupantServiceServer = require(ServerScriptService.Features.Occupant.OccupantServiceServer)
local harlow = require(ServerScriptService.Commands.OccupantStageServer)

return function()
	describe("OccupantStageServer", function()
		local original
		local answer = { true, "frozen" }
		local asked = nil

		beforeAll(function()
			original = OccupantServiceServer.stage
			OccupantServiceServer.stage = function(_self, player, action, target)
				asked = { player = player, action = action, target = target }
				return answer[1], answer[2]
			end
		end)

		afterAll(function()
			OccupantServiceServer.stage = original
		end)

		beforeEach(function()
			asked = nil
			answer = { true, "frozen" }
		end)

		it("stages him for the caller and says what happened", function()
			local caller = { Name = "dev" }
			local message = harlow({ Executor = caller }, "Freeze")
			expect(asked.player).to.equal(caller)
			expect(asked.action).to.equal("freeze")
			expect(message:find("frozen")).to.be.ok()
		end)

		it("passes the player to chase", function()
			local runner = { Name = "runner" }
			harlow({ Executor = {} }, "chase", runner)
			expect(asked.action).to.equal("chase")
			expect(asked.target).to.equal(runner)
		end)

		it("refuses an unknown action without staging, listing the actions", function()
			local message = harlow({ Executor = {} }, "dance")
			expect(asked).to.equal(nil)
			expect(message:find("freeze")).to.be.ok()
		end)

		it("asks for a player before a chase", function()
			local message = harlow({ Executor = {} }, "chase")
			expect(asked).to.equal(nil)
			expect(message:find("player")).to.be.ok()
		end)

		it("reports why nothing was done", function()
			answer = { false, "no shift is running" }
			local message = harlow({ Executor = {} }, "calm")
			expect(message:find("Nothing done: no shift is running")).to.be.ok()
		end)
	end)
end
