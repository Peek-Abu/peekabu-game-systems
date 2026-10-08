--!strict
--[=[
	Unit tests for the SetSurface Cmdr command implementation.
	Mock strategy: patch CustomizationService.setSurface/getAppearance inside beforeAll/afterAll (see
	AddCurrencyServer.spec for the rationale).

	The logic worth covering is the two sentinels. A stored selection is the COMPLETE state of the
	channel, so the service reads nil as "restore the rig's surface" — which means "keep this aspect"
	cannot be expressed as nil and has to be resolved HERE against what is stored. "-" keeps, "none"
	clears; conflating them is what would make setting a pattern silently wipe the texture.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)
local setSurfaceCommand = require(ServerScriptService.Commands.CustomizationSetSurfaceServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("CustomizationSetSurfaceServer", function()
		local _origSet, _origGet
		local calls: { { channel: string, pattern: string?, texture: string? } } = {}
		local nextResult = true
		local nextReason: string? = nil
		local storedSurfaces: { [string]: { pattern: string?, texture: string? } } = {}

		beforeAll(function()
			_origSet = CustomizationService.setSurface
			_origGet = CustomizationService.getAppearance
			CustomizationService.getAppearance = function(_self: any, _userId: number)
				return {
					cosmetics = {},
					accessories = {},
					body = {},
					headType = "Uncovered",
					surfaces = storedSurfaces,
				}
			end
			CustomizationService.setSurface = function(
				_self: any,
				_userId: number,
				channel: string,
				pattern: string?,
				texture: string?
			)
				table.insert(calls, { channel = channel, pattern = pattern, texture = texture })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			CustomizationService.setSurface = _origSet
			CustomizationService.getAppearance = _origGet
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
			nextReason = nil
			storedSurfaces = {}
		end)

		it("forwards both aspects when supplied", function()
			setSurfaceCommand(nil, fakePlayer, "backpack1", "Back2", "Fern")
			expect(#calls).to.equal(1)
			expect(calls[1].channel).to.equal("backpack1")
			expect(calls[1].pattern).to.equal("Back2")
			expect(calls[1].texture).to.equal("Fern")
		end)

		-- The regression that motivated the sentinel split: changing only the pattern must not wipe a
		-- texture the player already had.
		it("carries the stored aspect through when '-' is passed", function()
			storedSurfaces.clothing1 = { pattern = "Skin1", texture = "Fern" }

			setSurfaceCommand(nil, fakePlayer, "clothing1", "Skin2", "-")
			expect(calls[1].pattern).to.equal("Skin2")
			expect(calls[1].texture).to.equal("Fern")

			setSurfaceCommand(nil, fakePlayer, "clothing1", "-", "Ivy")
			expect(calls[2].pattern).to.equal("Skin1")
			expect(calls[2].texture).to.equal("Ivy")
		end)

		it("passes nil for '-' when the channel has nothing stored yet", function()
			setSurfaceCommand(nil, fakePlayer, "clothing1", "Skin2", "-")
			expect(calls[1].pattern).to.equal("Skin2")
			expect(calls[1].texture).to.equal(nil)
		end)

		it("clears just one aspect on 'none', keeping the other", function()
			storedSurfaces.clothing1 = { pattern = "Skin1", texture = "Fern" }

			setSurfaceCommand(nil, fakePlayer, "clothing1", "-", "none")
			expect(calls[1].pattern).to.equal("Skin1")
			expect(calls[1].texture).to.equal(nil)
		end)

		it("clears the whole channel when both are 'none'", function()
			storedSurfaces.clothing1 = { pattern = "Skin1", texture = "Fern" }

			setSurfaceCommand(nil, fakePlayer, "clothing1", "none", "none")
			expect(calls[1].pattern).to.equal(nil)
			expect(calls[1].texture).to.equal(nil)
		end)

		it("surfaces the service's specific failure reason", function()
			nextResult = false
			nextReason = '"kneepads" is not a registered surface channel'
			local message = setSurfaceCommand(nil, fakePlayer, "kneepads", "-", "-")
			expect(message:find("not a registered surface channel", 1, true)).to.be.ok()
		end)
	end)
end
