--[[
	Unit tests for the cosmeticequip command: CosmeticService.equip and currentEmployee are patched.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticService = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local command = require(ServerScriptService.Commands.CosmeticEquipServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

return function()
	describe("CosmeticEquipServer", function()
		local originalEquip, originalCurrent
		local calls = {}
		local result = { true, nil }

		beforeAll(function()
			originalEquip = CosmeticService.equip
			originalCurrent = CosmeticService.currentEmployee
			CosmeticService.equip = function(_self, userId, change)
				table.insert(calls, { userId = userId, change = change })
				return result[1], result[2]
			end
			CosmeticService.currentEmployee = function()
				return "Cappy"
			end
		end)

		afterAll(function()
			CosmeticService.equip = originalEquip
			CosmeticService.currentEmployee = originalCurrent
		end)

		beforeEach(function()
			calls = {}
			result = { true, nil }
		end)

		it("builds each kind of change", function()
			command(nil, fakePlayer, "employee", "Cappy")
			command(nil, fakePlayer, "skin", "Cappy.PJ", 2)
			command(nil, fakePlayer, "skin", "Cappy.PJ")
			command(nil, fakePlayer, "idle", "Cappy.Classic")
			command(nil, fakePlayer, "emote", "Cappy.CocoaSip", 3)
			command(nil, fakePlayer, "sticker", "-", 1)
			expect(#calls).to.equal(6)
			expect(calls[1].change.kind).to.equal("employee")
			expect(calls[2].change.style).to.equal(2)
			expect(calls[3].change.style).to.equal(1)
			expect(calls[4].change.employee).to.equal("Cappy")
			expect(calls[5].change.slot).to.equal(3)
			expect(calls[5].change.employee).to.equal("Cappy")
			expect(calls[6].change.id).to.equal("")
			expect(calls[1].userId).to.equal(42)
		end)

		it("needs a slot for emotes and stickers, and a known kind", function()
			expect(command(nil, fakePlayer, "emote", "Cappy.CocoaSip"):find("slot", 1, true)).to.be.ok()
			expect(command(nil, fakePlayer, "hat", "Cappy.PJ"):find("unknown kind", 1, true)).to.be.ok()
			expect(#calls).to.equal(0)
		end)

		it("passes the service's reason through", function()
			result = { false, "locked during a shift" }
			expect(command(nil, fakePlayer, "employee", "Cappy"):find("locked during a shift", 1, true)).to.be.ok()
		end)
	end)
end
