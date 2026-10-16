local CargoRegistry = require(script.Parent.CargoRegistry)

-- Kind, category, reference value, range (docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md §3.1).
local EXPECTED = {
	{ "rubbishBag", "trash", 10, 10, 10 },
	{ "dustBag", "trash", 15, 15, 15 },
	{ "recyclingBox", "trash", 15, 15, 15 },
	{ "bottleBag", "trash", 15, 15, 15 },
	{ "officePlant", "salvage", 68, 45, 90 },
	{ "plaque", "salvage", 75, 50, 100 },
	{ "monitor", "salvage", 80, 40, 120 },
	{ "waterJug", "salvage", 85, 60, 110 },
	{ "coffeeMachine", "salvage", 160, 120, 200 },
	{ "fishTank", "salvage", 260, 200, 320 },
	{ "goldenStapler", "salvage", 240, 180, 300 },
	{ "filingCabinet", "salvage", 340, 260, 420 },
	-- The small pocketable valuables (docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md §5).
	{ "coffeeMug", "salvage", 55, 40, 70 },
	{ "wristwatch", "salvage", 130, 90, 170 },
	{ "deskClock", "salvage", 75, 55, 95 },
	{ "snowGlobe", "salvage", 85, 60, 110 },
	{ "keyring", "salvage", 45, 30, 60 },
}

local SMALL_VALUABLES = { "coffeeMug", "wristwatch", "deskClock", "snowGlobe", "keyring" }

return function()
	it("holds the sixteen office items and the dust bag", function()
		expect(#CargoRegistry.ids()).to.equal(17)
	end)

	it("matches the spec's kinds, reference values and ranges", function()
		for _, row in EXPECTED do
			local def = CargoRegistry.get(row[1])
			expect(def).to.be.ok()
			expect(def.category).to.equal(row[2])
			expect(def.value).to.equal(row[3])
			expect(def.valueMin).to.equal(row[4])
			expect(def.valueMax).to.equal(row[5])
		end
	end)

	it("makes every valuable grimy and no trash", function()
		for _, id in CargoRegistry.ids() do
			local def = CargoRegistry.get(id)
			expect(def.grimy).to.equal(def.category == "salvage")
		end
	end)

	it("lets only tiny or medium non-greed valuables be buried", function()
		local buriable = {}
		for _, id in CargoRegistry.ids() do
			local def = CargoRegistry.get(id)
			if def.buriable then
				expect(def.category).to.equal("salvage")
				expect(def.greed).to.equal(false)
				expect(def.size == "tiny" or def.size == "medium").to.equal(true)
				table.insert(buriable, id)
			end
		end
		expect(table.concat(buriable, ",")).to.equal("coffeeMug,keyring,monitor,officePlant,plaque,wristwatch")
	end)

	it("gives jackpots to the monitor, plaque, coffee machine, golden stapler and five small valuables", function()
		local jackpots = {}
		for _, id in CargoRegistry.ids() do
			local jackpot = CargoRegistry.get(id).jackpot
			if jackpot ~= nil then
				expect(jackpot.chance > 0 and jackpot.chance < 0.5).to.equal(true)
				expect(jackpot.multiplier > 1).to.equal(true)
				expect(#jackpot.name > 0).to.equal(true)
				table.insert(jackpots, id)
			end
		end
		expect(table.concat(jackpots, ",")).to.equal(
			"coffeeMachine,coffeeMug,deskClock,goldenStapler,keyring,monitor,plaque,snowGlobe,wristwatch"
		)
		expect(CargoRegistry.get("monitor").jackpot.name).to.equal("Gold-trim")
	end)

	it("lists ids sorted", function()
		local ids = CargoRegistry.ids()
		for index = 2, #ids do
			expect(ids[index - 1] < ids[index]).to.equal(true)
		end
	end)

	it("marks exactly the three greed targets", function()
		local greed = CargoRegistry.greedIds()
		expect(#greed).to.equal(3)
		expect(greed[1]).to.equal("filingCabinet")
		expect(greed[2]).to.equal("fishTank")
		expect(greed[3]).to.equal("goldenStapler")
	end)

	it("carries the spec's traits", function()
		expect(CargoRegistry.get("rubbishBag").throwable).to.equal(true)
		expect(CargoRegistry.get("dustBag").throwable).to.equal(true)
		expect(CargoRegistry.get("recyclingBox").spills).to.equal(true)
		expect(CargoRegistry.get("bottleBag").rattly).to.equal(true)
		expect(CargoRegistry.get("officePlant").blocksView).to.equal(true)
		expect(CargoRegistry.get("plaque").size).to.equal("tiny")
		expect(CargoRegistry.get("monitor").fragile).to.equal(true)
		expect(CargoRegistry.get("waterJug").splashes).to.equal(true)
		expect(CargoRegistry.get("coffeeMachine").rattly).to.equal(true)
		local tank = CargoRegistry.get("fishTank")
		expect(tank.fragile and tank.rattly and tank.size == "heavy").to.equal(true)
		local stapler = CargoRegistry.get("goldenStapler")
		expect(stapler.hidden and stapler.size == "tiny").to.equal(true)
		expect(CargoRegistry.get("filingCabinet").size).to.equal("bulky")
	end)

	it("never rolls the dust bag or a greed target onto the open floor", function()
		expect(CargoRegistry.get("dustBag").spawnWeight).to.equal(0)
		for _, id in CargoRegistry.greedIds() do
			expect(CargoRegistry.get(id).spawnWeight).to.equal(0)
		end
	end)

	describe("small pocketable valuables", function()
		it("are tiny, grimy, on the open floor and in desks", function()
			for _, id in SMALL_VALUABLES do
				local def = CargoRegistry.get(id)
				expect(def.size).to.equal("tiny")
				expect(def.grimy).to.equal(true)
				expect(def.greed).to.equal(false)
				expect(def.spawnWeight > 0).to.equal(true)
				expect(def.deskWeight > 0).to.equal(true)
			end
		end)

		it("carry their own proxy boxes, small enough to hold in one hand", function()
			for _, id in SMALL_VALUABLES do
				local size = CargoRegistry.get(id).partSize
				expect(math.max(size.X, size.Y, size.Z) < 1.65).to.equal(true)
			end
			expect(CargoRegistry.get("coffeeMug").partSize).to.equal(Vector3.new(1, 1, 0.8))
			expect(CargoRegistry.get("plaque").partSize).to.equal(Vector3.new(1, 0.4, 0.8))
		end)

		it("make the small kinds about two thirds of the open-floor valuables roll", function()
			local small, big = 0, 0
			for _, id in CargoRegistry.ids() do
				local def = CargoRegistry.get(id)
				if def.category == "salvage" and not def.greed and not def.hidden then
					if def.size == "tiny" or def.size == "light" then
						small += def.spawnWeight
					else
						big += def.spawnWeight
					end
				end
			end
			expect(small / (small + big) >= 0.65).to.equal(true)
		end)

		it("has no desk phone (cut by the user)", function()
			expect(CargoRegistry.has("deskPhone")).to.equal(false)
		end)

		it("keeps the mug and the snow globe fragile and the keyring rattly", function()
			expect(CargoRegistry.get("coffeeMug").fragile).to.equal(true)
			expect(CargoRegistry.get("snowGlobe").fragile).to.equal(true)
			expect(CargoRegistry.get("keyring").rattly).to.equal(true)
		end)
	end)

	it("returns nil for an unknown id", function()
		expect(CargoRegistry.get("spaceship")).to.equal(nil)
		expect(CargoRegistry.has("spaceship")).to.equal(false)
	end)
end
