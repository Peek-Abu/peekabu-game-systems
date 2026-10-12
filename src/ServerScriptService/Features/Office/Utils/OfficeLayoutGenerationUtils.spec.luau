local Server = game:GetService("ServerScriptService").Features.Office
local Gen = require(script.Parent.OfficeLayoutGenerationUtils)
local Base = require(Server.Data.OfficeLayoutConstants).LAYOUT
local Rules = require(Server.Rules.OfficeLayoutRules)
local Spawn = require(script.Parent.OfficeSpawnUtils)
local SpawnRules = require(Server.Rules.OfficeSpawnRules)
local Constants = require(Server.Data.OfficeConstants)
return function()
	describe("seeded room wing", function()
		it("adds five rooms without mutating the authored core", function()
			local n = #Base.rooms
			local layout = Gen.generate(Base, 1)
			expect(#layout.rooms).to.equal(n + 5)
			expect(#Base.rooms).to.equal(n)
			expect(layout.startRoom).to.equal(Base.startRoom)
		end)
		it("reproduces a seed and varies geometry and doors across seeds", function()
			local a = Gen.generate(Base, 1)
			local b = Gen.generate(Base, 1)
			local changed = false
			expect(a.rooms[8].maxX).to.equal(b.rooms[8].maxX)
			for seed = 2, 20 do
				local c = Gen.generate(Base, seed)
				changed = changed or c.rooms[8].maxX ~= a.rooms[8].maxX or c.doors[#c.doors].z ~= a.doors[#a.doors].z
			end
			expect(changed).to.equal(true)
		end)
		it("has reachable rooms, valid markers/routes and guaranteed shift contents over 30 seeds", function()
			for seed = 1, 30 do
				local layout = Gen.generate(Base, seed)
				local ok, errors = Rules.validate(layout)
				if not ok then
					error(table.concat(errors, "\n"))
				end
				expect(Rules.checkCapacity(layout)).to.equal(true)
				expect(Rules.checkRoute(layout)).to.equal(true)
				local plan = Spawn.roll(
					layout,
					{ quota = 350, variant = "A", piles = Constants.PILES, salvage = Constants.SALVAGE },
					Random.new(seed)
				)
				local valid, reason = SpawnRules.check(plan, layout, 350)
				if not valid then
					error(reason)
				end
				expect(valid).to.equal(true)
			end
		end)
	end)
end
