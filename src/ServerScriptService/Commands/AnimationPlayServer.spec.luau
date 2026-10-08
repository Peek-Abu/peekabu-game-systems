--[=[
	Unit tests for the AnimPlay Cmdr command implementation. Mock strategy: patch AnimationService.play
	(the AddCurrencyServer.spec pattern) — the command's own logic is arg forwarding and message shaping.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local animPlayCommand = require(ServerScriptService.Commands.AnimationPlayServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

return function()
	describe("AnimationPlayServer", function()
		local _origPlay
		local calls = {}
		local nextOk = true
		local nextReason = nil

		beforeAll(function()
			_origPlay = AnimationService.play
			AnimationService.play = function(_self, player, id, options)
				table.insert(calls, { player = player, id = id, options = options })
				return nextOk, nextReason
			end
		end)

		afterAll(function()
			AnimationService.play = _origPlay
		end)

		beforeEach(function()
			calls = {}
			nextOk = true
			nextReason = nil
		end)

		it("routes through the grant entry point with the target, id, speed and variant", function()
			local message = animPlayCommand(nil, fakePlayer, "testleap", 1.5, 1)
			expect(#calls).to.equal(1)
			expect(calls[1].player).to.equal(fakePlayer)
			expect(calls[1].id).to.equal("testleap")
			expect(calls[1].options.speed).to.equal(1.5)
			expect(calls[1].options.variant).to.equal(1)
			expect(message:find("Granted", 1, true)).to.be.ok()
		end)

		it("leaves the variant to the server when it is omitted", function()
			animPlayCommand(nil, fakePlayer, "testleap", 1, nil)
			expect(calls[1].options.variant).to.equal(nil)
		end)

		it("surfaces the service's refusal reason", function()
			nextOk = false
			nextReason = '"idle" is not a replicable action (locomotion stays local)'
			local message = animPlayCommand(nil, fakePlayer, "idle", 1, nil)
			expect(message:find("not a replicable action", 1, true)).to.be.ok()
		end)
	end)
end
