--!strict
--[=[
	Unit tests for the SetCosmeticColor Cmdr command implementation.
	Mock strategy: patch the CustomizationService methods inside beforeAll/afterAll (see
	AddCurrencyServer.spec for the rationale).

	The logic worth covering is that this is a RECOLOUR, not a re-equip: it must carry the currently
	equipped id and the other colour channels through untouched, and route accessories by slot while
	every other category is a single selection.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)
local setCosmeticColorCommand = require(ServerScriptService.Commands.CustomizationSetCosmeticColorServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("CustomizationSetCosmeticColorServer", function()
		local _origGet, _origCosmetic, _origAccessory
		local appearance: any = nil
		local cosmeticCalls: { any } = {}
		local accessoryCalls: { any } = {}

		beforeAll(function()
			_origGet = CustomizationService.getAppearance
			_origCosmetic = CustomizationService.equipCosmetic
			_origAccessory = CustomizationService.equipAccessory
			CustomizationService.getAppearance = function(_self: any, _userId: number)
				return appearance
			end
			CustomizationService.equipCosmetic = function(
				_self: any,
				_userId: number,
				category: string,
				id: string,
				colors: any
			)
				table.insert(cosmeticCalls, { category = category, id = id, colors = colors })
				return true, nil
			end
			CustomizationService.equipAccessory = function(
				_self: any,
				_userId: number,
				slot: number,
				id: string,
				colors: any
			)
				table.insert(accessoryCalls, { slot = slot, id = id, colors = colors })
				return true, nil
			end
		end)

		afterAll(function()
			CustomizationService.getAppearance = _origGet
			CustomizationService.equipCosmetic = _origCosmetic
			CustomizationService.equipAccessory = _origAccessory
		end)

		beforeEach(function()
			cosmeticCalls = {}
			accessoryCalls = {}
			appearance = {
				cosmetics = { hair = { id = "Hair9", colors = {} } },
				accessories = { { id = "Round Glasses", colors = {} } },
				body = {},
				headType = "Uncovered",
				surfaces = {},
			}
		end)

		-- Cmdr's integer type stops non-integers, not range; both of these are used as indices.
		it("refuses a colour channel below 1 without touching the service", function()
			local message = setCosmeticColorCommand(nil, fakePlayer, "hair", 1, 2, 3, 0, 1)
			expect(message:find("must be 1 or higher", 1, true)).to.be.ok()
			expect(#cosmeticCalls).to.equal(0)
		end)

		it("refuses an out-of-range accessory slot without touching the service", function()
			local message = setCosmeticColorCommand(nil, fakePlayer, "accessory", 1, 2, 3, 1, 99)
			expect(message:find("Accessory slot must be", 1, true)).to.be.ok()
			expect(#accessoryCalls).to.equal(0)
		end)

		it("reports when no profile is loaded", function()
			appearance = nil
			expect(setCosmeticColorCommand(nil, fakePlayer, "hair", 1, 2, 3, 1, 1):find("No profile", 1, true)).to.be.ok()
		end)

		it("reports when nothing is equipped in that category", function()
			appearance.cosmetics = {}
			local message = setCosmeticColorCommand(nil, fakePlayer, "hair", 1, 2, 3, 1, 1)
			expect(message:find("nothing equipped", 1, true)).to.be.ok()
			expect(#cosmeticCalls).to.equal(0)
		end)

		it("re-equips the SAME id with the new colour, never a different cosmetic", function()
			setCosmeticColorCommand(nil, fakePlayer, "hair", 255, 0, 0, 1, 1)
			expect(#cosmeticCalls).to.equal(1)
			expect(cosmeticCalls[1].id).to.equal("Hair9")
			expect(cosmeticCalls[1].colors[1].source).to.equal("rgb")
			expect(cosmeticCalls[1].colors[1].r).to.equal(255)
		end)

		-- A recolour of channel 2 must not wipe channel 1, which a naive rebuild of the colour list
		-- would do.
		it("carries the other colour channels through untouched", function()
			appearance.cosmetics.hair = { id = "Hair9", colors = { { source = "rgb", r = 9, g = 9, b = 9 } } }
			setCosmeticColorCommand(nil, fakePlayer, "hair", 1, 2, 3, 2, 1)
			local colors = cosmeticCalls[1].colors
			expect(colors[1].r).to.equal(9)
			expect(colors[2].r).to.equal(1)
		end)

		it("routes the accessory category by SLOT", function()
			setCosmeticColorCommand(nil, fakePlayer, "accessory", 10, 20, 30, 1, 1)
			expect(#accessoryCalls).to.equal(1)
			expect(accessoryCalls[1].slot).to.equal(1)
			expect(accessoryCalls[1].id).to.equal("Round Glasses")
			expect(#cosmeticCalls).to.equal(0)
		end)

		it("reports an empty accessory slot rather than equipping something", function()
			local message = setCosmeticColorCommand(nil, fakePlayer, "accessory", 1, 2, 3, 1, 3)
			expect(message:find("accessory slot 3", 1, true)).to.be.ok()
			expect(#accessoryCalls).to.equal(0)
		end)
	end)
end
