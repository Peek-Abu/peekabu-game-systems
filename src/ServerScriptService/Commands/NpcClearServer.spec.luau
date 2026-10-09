--[[
	Unit tests for the npcclear Cmdr command (see NpcSpawnServer.spec for the mock strategy).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local NpcService = require(ServerScriptService.Features.Npc.NpcServiceServer)
local clearCommand = require(ServerScriptService.Commands.NpcClearServer)

return function()
	describe("NpcClearServer", function()
		local originalClear
		local lastKind = "unset"

		beforeAll(function()
			originalClear = NpcService.clear
			NpcService.clear = function(_self, kind)
				lastKind = kind
				return 3
			end
		end)

		afterAll(function()
			NpcService.clear = originalClear
		end)

		it("clears every NPC", function()
			expect(clearCommand(nil, nil):find("Removed 3 NPC")).to.be.ok()
			expect(lastKind).to.equal(nil)
		end)

		it("clears one kind", function()
			expect(clearCommand(nil, "wolf"):find('Removed 3 "wolf"')).to.be.ok()
			expect(lastKind).to.equal("wolf")
		end)
	end)
end
