--[[
	Unit tests for the dailyrewardreset Cmdr command. Mock strategy (the CurrencyAddServer.spec convention):
	patch DailyRewardService.reset inside beforeAll/afterAll.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local DailyRewardService = require(ServerScriptService.Features.DailyReward.DailyRewardServiceServer)
local resetCommand = require(ServerScriptService.Commands.DailyRewardResetServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

return function()
	describe("DailyRewardResetServer", function()
		local originalReset
		local result = true

		beforeAll(function()
			originalReset = DailyRewardService.reset
			DailyRewardService.reset = function()
				return result
			end
		end)

		afterAll(function()
			DailyRewardService.reset = originalReset
		end)

		it("reports a cleared streak", function()
			result = true
			expect(resetCommand(nil, fakePlayer):find("Cleared")).to.be.ok()
		end)

		it("reports when there was nothing to clear", function()
			result = false
			expect(resetCommand(nil, fakePlayer):find("Nothing to clear")).to.be.ok()
		end)
	end)
end
