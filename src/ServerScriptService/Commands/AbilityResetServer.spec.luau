--[[
	Unit tests for the abilityreset Cmdr command. Mock strategy (the CurrencyAddServer.spec convention): patch
	AbilityServiceServer.resetCooldown inside beforeAll/afterAll.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local AbilityService = require(ServerScriptService.Features.Ability.AbilityServiceServer)
local resetCommand = require(ServerScriptService.Commands.AbilityResetServer)

local me = { UserId = 41, Name = "Me" }
local other = { UserId = 42, Name = "Other" }

return function()
	describe("AbilityResetServer", function()
		local originalReset
		local result = true
		local reset = nil

		beforeAll(function()
			originalReset = AbilityService.resetCooldown
			AbilityService.resetCooldown = function(_self, player)
				reset = player
				return result
			end
		end)

		afterAll(function()
			AbilityService.resetCooldown = originalReset
		end)

		it("resets the named player's cooldown", function()
			result = true
			expect(resetCommand({ Executor = me }, other):find("Other")).to.be.ok()
			expect(reset).to.equal(other)
		end)

		it("resets the admin's own cooldown with no player named", function()
			result = true
			expect(resetCommand({ Executor = me }, nil):find("Me")).to.be.ok()
			expect(reset).to.equal(me)
		end)

		it("says so when there was no cooldown to reset", function()
			result = false
			expect(resetCommand({ Executor = me }, other):find("already ready")).to.be.ok()
		end)
	end)
end
