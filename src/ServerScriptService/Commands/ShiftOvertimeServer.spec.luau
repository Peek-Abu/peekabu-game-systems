--[[
	Unit tests for the shiftovertime Cmdr command: the ShiftServiceServer method it calls is patched.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local shiftOvertime = require(ServerScriptService.Commands.ShiftOvertimeServer)

return function()
	describe("ShiftOvertimeServer", function()
		local original
		local answer = true

		beforeAll(function()
			original = ShiftServiceServer.forceOvertime
			ShiftServiceServer.forceOvertime = function()
				return answer
			end
		end)

		afterAll(function()
			ShiftServiceServer.forceOvertime = original
		end)

		it("says overtime started", function()
			answer = true
			expect(shiftOvertime({ Executor = {} }):find("Overtime")).to.be.ok()
		end)

		it("says why it could not", function()
			answer = false
			expect(shiftOvertime({ Executor = {} }):find("Not now")).to.be.ok()
		end)
	end)
end
