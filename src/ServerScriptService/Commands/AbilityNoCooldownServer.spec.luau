--[[
	Unit tests for the abilitynocooldown Cmdr command. Mock strategy (the CurrencyAddServer.spec convention): patch
	AbilityServiceServer.setNoCooldown inside beforeAll/afterAll.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local AbilityService = require(ServerScriptService.Features.Ability.AbilityServiceServer)
local noCooldownCommand = require(ServerScriptService.Commands.AbilityNoCooldownServer)

local me = { UserId = 41, Name = "Me" }
local other = { UserId = 42, Name = "Other" }

return function()
	describe("AbilityNoCooldownServer", function()
		local originalSet
		local calls = {}

		beforeAll(function()
			originalSet = AbilityService.setNoCooldown
			AbilityService.setNoCooldown = function(_self, player, on)
				table.insert(calls, { player = player, on = on })
			end
		end)

		afterAll(function()
			AbilityService.setNoCooldown = originalSet
		end)

		it("turns no-cooldown mode on for the named player", function()
			table.clear(calls)
			local message = noCooldownCommand({ Executor = me }, true, other)
			expect(calls[1].player).to.equal(other)
			expect(calls[1].on).to.equal(true)
			expect(message:find("on")).to.be.ok()
		end)

		it("turns it off for the admin with no player named", function()
			table.clear(calls)
			local message = noCooldownCommand({ Executor = me }, false, nil)
			expect(calls[1].player).to.equal(me)
			expect(calls[1].on).to.equal(false)
			expect(message:find("off")).to.be.ok()
		end)
	end)
end
