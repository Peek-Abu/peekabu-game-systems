--[[
	The pure parts of OfficeShiftSpawnSystem: `fresh`, `spotFrame` and `roll`. Placing (`place`, `placeOvertime`) and
	`watch` drive the live Cargo and Vacuum services; OfficeServiceServer.spec's shifts run them.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeShiftSpawnSystem = require(script.Parent.OfficeShiftSpawnSystem)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)
local OfficeLayoutGenerationUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutGenerationUtils)
local OfficeSpawnRules = require(ServerScriptService.Features.Office.Rules.OfficeSpawnRules)
local OfficeSpawnUtils = require(ServerScriptService.Features.Office.Utils.OfficeSpawnUtils)

local LAYOUT = OfficeLayoutConstants.LAYOUT

return function()
	describe("fresh", function()
		it("is nil for trash (no roll)", function()
			expect(OfficeShiftSpawnSystem.fresh(nil)).to.equal(nil)
		end)

		it("keeps the roll's base and variant, fully grimy and unappraised", function()
			local appraisal = OfficeShiftSpawnSystem.fresh({ base = 40, variant = "gold" })
			expect(appraisal.base).to.equal(40)
			expect(appraisal.variant).to.equal("gold")
			expect(appraisal.clean).to.equal(0)
			expect(appraisal.appraised).to.equal(false)
		end)
	end)

	describe("spotFrame", function()
		it("stands a floor marker on the floor", function()
			local marker = { id = "m", kind = "item", room = "r", x = 4, z = -2 }
			expect(OfficeShiftSpawnSystem.spotFrame(nil, marker)).to.equal(
				OfficeConstants.ORIGIN * CFrame.new(4, 0, -2)
			)
		end)

		it("stands a counter marker on the counter's top when no office stands", function()
			local marker = { id = "c", kind = "counter", room = "r", x = 1, z = 2 }
			expect(OfficeShiftSpawnSystem.spotFrame(nil, marker)).to.equal(
				OfficeConstants.ORIGIN * CFrame.new(1, OfficeConstants.COUNTER_SIZE.Y, 2)
			)
		end)
	end)

	describe("roll", function()
		local function options(seed)
			return { seed = seed, variant = "B", quota = 0, map = "office" }
		end

		it("rolls the same plan for the same options", function()
			local layout = OfficeLayoutGenerationUtils.generate(LAYOUT, 2)
			local a = OfficeShiftSpawnSystem.roll(layout, options(2))
			local b = OfficeShiftSpawnSystem.roll(layout, options(2))
			expect(a.value).to.equal(b.value)
			expect(#a.piles).to.equal(#b.piles)
			expect(#a.items).to.equal(#b.items)
		end)

		it("is the first roll from the seed, with the office's spawn numbers, when it meets the guarantees", function()
			local spawn = OfficeConstants.SPAWN_BY_MAP.office
			for seed = 1, 5 do
				local layout = OfficeLayoutGenerationUtils.generate(LAYOUT, seed)
				local first = OfficeSpawnUtils.roll(layout, {
					quota = 0,
					variant = "B",
					dirtyRooms = spawn.dirtyRooms,
					pilesPerRoom = spawn.pilesPerRoom,
					valuables = spawn.valuables,
					valueScale = spawn.valueScale,
					topUpMax = spawn.topUpMax,
				}, Random.new(seed))
				if OfficeSpawnRules.check(first, layout, 0) then
					local plan = OfficeShiftSpawnSystem.roll(layout, options(seed))
					expect(plan.value).to.equal(first.value)
					expect(#plan.piles).to.equal(#first.piles)
					expect(#plan.items).to.equal(#first.items)
				end
				task.wait()
			end
		end)
	end)
end
