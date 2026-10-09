--[=[
	Unit tests for the AnimReport Cmdr command implementation. The registry summary runs against the
	REAL registry; only the probe request is patched.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local animReportCommand = require(ServerScriptService.Commands.AnimationReportServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("AnimationReportServer", function()
		local _origProbe
		local calls = {}

		beforeAll(function()
			_origProbe = AnimationService.requestAssetProbe
			AnimationService.requestAssetProbe = function(_self, player)
				table.insert(calls, player)
			end
		end)

		afterAll(function()
			AnimationService.requestAssetProbe = _origProbe
		end)

		beforeEach(function()
			calls = {}
		end)

		it("summarizes the real registry and probes the executor's client", function()
			local message = animReportCommand({ Executor = fakePlayer })
			expect(message:find("locomotion", 1, true)).to.be.ok()
			expect(#calls).to.equal(1)
			expect(calls[1]).to.equal(fakePlayer)
		end)

		it("still summarizes with no executor (e.g. server console), skipping the probe", function()
			local message = animReportCommand(nil)
			expect(message:find("Animation registry", 1, true)).to.be.ok()
			expect(#calls).to.equal(0)
		end)
	end)
end
