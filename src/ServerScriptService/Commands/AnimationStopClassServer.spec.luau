--[=[
	Unit tests for the AnimStopClass Cmdr command implementation. The refusal rule (only `attack` is
	bulk-stoppable) is asserted through the REAL validateStopClass — only the grant-ending half is patched.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local animStopClassCommand = require(ServerScriptService.Commands.AnimationStopClassServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

return function()
	describe("AnimationStopClassServer", function()
		local _origStopAttacks
		local calls = {}

		beforeAll(function()
			_origStopAttacks = AnimationService.stopAttacks
			AnimationService.stopAttacks = function(_self, player)
				table.insert(calls, { player = player })
				return 2
			end
		end)

		afterAll(function()
			AnimationService.stopAttacks = _origStopAttacks
		end)

		beforeEach(function()
			calls = {}
		end)

		it("ends attack-class actions and reports how many", function()
			local message = animStopClassCommand(nil, fakePlayer, "attack")
			expect(#calls).to.equal(1)
			expect(message:find("Stopped 2", 1, true)).to.be.ok()
		end)

		it("refuses protected without ending anything", function()
			local message = animStopClassCommand(nil, fakePlayer, "protected")
			expect(#calls).to.equal(0)
			expect(message:find("Refused", 1, true)).to.be.ok()
		end)

		it("refuses ambient without ending anything", function()
			local message = animStopClassCommand(nil, fakePlayer, "ambient")
			expect(#calls).to.equal(0)
			expect(message:find("Refused", 1, true)).to.be.ok()
		end)

		it("refuses an unknown class without ending anything", function()
			local message = animStopClassCommand(nil, fakePlayer, "sometimes")
			expect(#calls).to.equal(0)
			expect(message:find("Refused", 1, true)).to.be.ok()
		end)
	end)
end
