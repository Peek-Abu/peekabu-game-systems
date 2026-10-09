--[[
	Unit tests for the roundend Cmdr command (see RoundStartServer.spec for the mock strategy).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local RoundService = require(ServerScriptService.Features.Round.RoundServiceServer)
local roundEnd = require(ServerScriptService.Commands.RoundEndServer)

return function()
	describe("RoundEndServer", function()
		local originalEndRound
		local originalGetPhase
		local phase = { phase = "running", round = 3 }
		local endedWith = nil

		beforeAll(function()
			originalEndRound = RoundService.endRound
			originalGetPhase = RoundService.getPhase
			RoundService.endRound = function(_self, outcome)
				if phase.phase ~= "running" then
					return false
				end
				endedWith = outcome
				phase = { phase = "results", round = 3, outcome = outcome }
				return true
			end
			RoundService.getPhase = function()
				return phase
			end
		end)

		afterAll(function()
			RoundService.endRound = originalEndRound
			RoundService.getPhase = originalGetPhase
		end)

		it("ends the running round with the outcome", function()
			local message = roundEnd(nil, "quota")
			expect(endedWith).to.equal("quota")
			expect(message:find("Round 3 ended: quota")).to.be.ok()
		end)

		it("reports when no round is running", function()
			local message = roundEnd(nil, "quota")
			expect(message:find("No round is running")).to.be.ok()
		end)
	end)
end
