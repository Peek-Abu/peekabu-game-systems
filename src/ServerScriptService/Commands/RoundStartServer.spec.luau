--[[
	Unit tests for the roundstart / roundend Cmdr commands. Mock strategy (the CurrencyAddServer.spec
	convention): patch the RoundService methods the commands call inside beforeAll/afterAll, so the live
	round is never touched.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local RoundService = require(ServerScriptService.Features.Round.RoundServiceServer)
local roundStart = require(ServerScriptService.Commands.RoundStartServer)

return function()
	describe("RoundStartServer", function()
		local originalStartNow
		local originalGetPhase
		local started = false
		local phase = { phase = "lobby", round = 0 }

		beforeAll(function()
			originalStartNow = RoundService.startNow
			originalGetPhase = RoundService.getPhase
			RoundService.startNow = function()
				if phase.phase ~= "lobby" then
					return false
				end
				started = true
				phase = { phase = "running", round = 1 }
				return true
			end
			RoundService.getPhase = function()
				return phase
			end
		end)

		afterAll(function()
			RoundService.startNow = originalStartNow
			RoundService.getPhase = originalGetPhase
		end)

		it("starts a round and reports its number", function()
			local message = roundStart(nil)
			expect(started).to.equal(true)
			expect(message:find("Round 1 started")).to.be.ok()
		end)

		it("reports the current phase when a round is already going", function()
			local message = roundStart(nil)
			expect(message:find("already running")).to.be.ok()
		end)
	end)
end
