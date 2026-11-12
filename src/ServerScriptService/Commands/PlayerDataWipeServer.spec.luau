--[[
	Unit tests for the datawipe Cmdr command. Mock strategy (the CurrencyAddServer.spec convention): patch
	PlayerDataServiceServer.wipe inside beforeAll/afterAll; the target is a fake player that records its kick.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local wipeCommand = require(ServerScriptService.Commands.PlayerDataWipeServer)

local function fakePlayer(userId: number, name: string)
	local player = { UserId = userId, Name = name, kicked = nil }
	function player:Kick(message: string)
		self.kicked = message
	end
	return player
end

return function()
	describe("PlayerDataWipeServer", function()
		local originalWipe
		local wiped = nil
		local okResult = true

		beforeAll(function()
			originalWipe = PlayerDataService.wipe
			PlayerDataService.wipe = function(_self, userId)
				wiped = userId
				if okResult then
					return true, nil
				end
				return false, "busy"
			end
		end)

		afterAll(function()
			PlayerDataService.wipe = originalWipe
		end)

		beforeEach(function()
			wiped = nil
		end)

		it("wipes the named player's save and sends them out to rejoin", function()
			okResult = true
			local target = fakePlayer(42, "Other")
			expect(wipeCommand({ Executor = fakePlayer(41, "Me") }, target):find("Other")).to.be.ok()
			expect(wiped).to.equal(42)
			expect(target.kicked).to.be.a("string")
		end)

		it("keeps the player in and reports why when the wipe is refused", function()
			okResult = false
			local target = fakePlayer(42, "Other")
			expect(wipeCommand({ Executor = fakePlayer(41, "Me") }, target):find("busy")).to.be.ok()
			expect(target.kicked).to.equal(nil)
		end)
	end)
end
