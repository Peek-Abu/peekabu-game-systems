--[=[
	Unit tests for the AnimTracks Cmdr command implementation (patched-service pattern).
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local animTracksCommand = require(ServerScriptService.Commands.AnimationTracksServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("AnimationTracksServer", function()
		local _origRequest
		local calls = {}

		beforeAll(function()
			_origRequest = AnimationService.requestTrackReport
			AnimationService.requestTrackReport = function(_self, player)
				table.insert(calls, player)
			end
		end)

		afterAll(function()
			AnimationService.requestTrackReport = _origRequest
		end)

		it("requests the report from the target's client and says where to read it", function()
			local message = animTracksCommand(nil, fakePlayer)
			expect(#calls).to.equal(1)
			expect(calls[1]).to.equal(fakePlayer)
			expect(message:find("client log", 1, true)).to.be.ok()
		end)
	end)
end
