--[=[
	Unit tests for the AnimStop Cmdr command implementation (patched-service pattern).
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local animStopCommand = require(ServerScriptService.Commands.AnimationStopServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

return function()
	describe("AnimationStopServer", function()
		local _origStop
		local calls = {}
		local nextOk = true
		local nextReason = nil

		beforeAll(function()
			_origStop = AnimationService.stop
			AnimationService.stop = function(_self, player, idOrLayer)
				table.insert(calls, { player = player, idOrLayer = idOrLayer })
				return nextOk, nextReason
			end
		end)

		afterAll(function()
			AnimationService.stop = _origStop
		end)

		beforeEach(function()
			calls = {}
			nextOk = true
			nextReason = nil
		end)

		it("forwards the target and the id or layer", function()
			local message = animStopCommand(nil, fakePlayer, "upper")
			expect(#calls).to.equal(1)
			expect(calls[1].player).to.equal(fakePlayer)
			expect(calls[1].idOrLayer).to.equal("upper")
			expect(message:find("Stopped", 1, true)).to.be.ok()
		end)

		it("surfaces the service's refusal reason", function()
			nextOk = false
			nextReason = '"idle" is neither a layer nor a replicable action'
			local message = animStopCommand(nil, fakePlayer, "idle")
			expect(message:find("neither a layer", 1, true)).to.be.ok()
		end)
	end)
end
