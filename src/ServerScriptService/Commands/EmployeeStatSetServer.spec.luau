--[[
	Unit tests for the employeestatset Cmdr command. Mock strategy (the CurrencyAddServer.spec convention): patch
	EmployeeServiceServer.overrideStats inside beforeAll/afterAll.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local EmployeeService = require(ServerScriptService.Features.Employee.EmployeeServiceServer)
local statSetCommand = require(ServerScriptService.Commands.EmployeeStatSetServer)

local me = { UserId = 41, Name = "Me" }
local other = { UserId = 42, Name = "Other" }

return function()
	describe("EmployeeStatSetServer", function()
		local original
		local calls = {}
		local result, reason = true, nil

		beforeAll(function()
			original = EmployeeService.overrideStats
			EmployeeService.overrideStats = function(_self, player, stats, bars)
				table.insert(calls, { player = player, stats = stats, bars = bars })
				return result, reason
			end
		end)

		afterAll(function()
			EmployeeService.overrideStats = original
		end)

		beforeEach(function()
			table.clear(calls)
			result, reason = true, nil
		end)

		it("sets one stat for the named player", function()
			expect(statSetCommand({ Executor = me }, "speed", "5", other):find("Other")).to.be.ok()
			expect(calls[1].player).to.equal(other)
			expect(#calls[1].stats).to.equal(1)
			expect(calls[1].stats[1]).to.equal("speed")
			expect(calls[1].bars).to.equal(5)
		end)

		it("sets every stat for the admin with all and no player named", function()
			statSetCommand({ Executor = me }, "ALL", "1", nil)
			expect(calls[1].player).to.equal(me)
			expect(#calls[1].stats).to.equal(5)
			expect(calls[1].bars).to.equal(1)
		end)

		it("resets to the employee's own bars", function()
			statSetCommand({ Executor = me }, "quiet", "reset", nil)
			expect(calls[1].bars).to.equal(nil)
		end)

		it("refuses an unknown stat or bars outside 1-5 without calling the service", function()
			expect(statSetCommand({ Executor = me }, "luck", "3", nil):find("stat")).to.be.ok()
			expect(statSetCommand({ Executor = me }, "speed", "6", nil):find("1 to 5")).to.be.ok()
			expect(statSetCommand({ Executor = me }, "speed", "2.5", nil):find("1 to 5")).to.be.ok()
			expect(#calls).to.equal(0)
		end)

		it("says when the character could not be rebuilt now", function()
			result, reason = false, "knocked down; it applies on the next spawn"
			expect(statSetCommand({ Executor = me }, "speed", "5", nil):find("next spawn")).to.be.ok()
		end)
	end)
end
