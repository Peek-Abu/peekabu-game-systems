--[[
	Unit tests for the npcspawn Cmdr command. Mock strategy (the CurrencyAddServer.spec convention): patch
	NpcService.spawn inside beforeAll/afterAll; the executor's character is a shaped fake.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local NpcService = require(ServerScriptService.Features.Npc.NpcServiceServer)
local spawnCommand = require(ServerScriptService.Commands.NpcSpawnServer)

local fakeRoot = {
	CFrame = CFrame.new(0, 5, 0),
	IsA = function(_self, className)
		return className == "BasePart"
	end,
}
local fakeCharacter = {
	FindFirstChild = function(_self, name)
		return if name == "HumanoidRootPart" then fakeRoot else nil
	end,
}

return function()
	describe("NpcSpawnServer", function()
		local originalSpawn
		local calls = {}

		beforeAll(function()
			originalSpawn = NpcService.spawn
			NpcService.spawn = function(_self, kind, cframe)
				table.insert(calls, { kind = kind, cframe = cframe })
				if kind == "missing" then
					return nil, "no template"
				end
				return {}, nil
			end
		end)

		afterAll(function()
			NpcService.spawn = originalSpawn
		end)

		beforeEach(function()
			calls = {}
		end)

		it("spawns in front of the executor", function()
			local message = spawnCommand({ Executor = { Character = fakeCharacter } }, "wolf")
			expect(message:find("Spawned")).to.be.ok()
			expect(calls[1].kind).to.equal("wolf")
			expect((calls[1].cframe.Position - Vector3.new(0, 5, -10)).Magnitude < 1e-3).to.equal(true)
		end)

		it("reports the service's refusal", function()
			expect(spawnCommand({ Executor = { Character = fakeCharacter } }, "missing"):find("no template")).to.be.ok()
		end)

		it("needs a character", function()
			expect(spawnCommand({ Executor = { Character = nil } }, "wolf"):find("need a character")).to.be.ok()
			expect(#calls).to.equal(0)
		end)
	end)
end
