local CargoRegistry = require(script.Parent.CargoRegistry)

local EXPECTED = {
	{ "rubbishBag", "trash", 10 },
	{ "dustBag", "trash", 15 },
	{ "recyclingBox", "trash", 15 },
	{ "bottleBag", "trash", 15 },
	{ "officePlant", "salvage", 20 },
	{ "plaque", "salvage", 25 },
	{ "monitor", "salvage", 30 },
	{ "waterJug", "salvage", 30 },
	{ "printer", "salvage", 40 },
	{ "coffeeMachine", "salvage", 50 },
	{ "fishTank", "salvage", 70 },
	{ "goldenStapler", "salvage", 80 },
	{ "filingCabinet", "salvage", 120 },
}

return function()
	it("holds the twelve office items and the dust bag", function()
		expect(#CargoRegistry.ids()).to.equal(13)
	end)

	it("matches the spec's kinds and values", function()
		for _, row in EXPECTED do
			local def = CargoRegistry.get(row[1])
			expect(def).to.be.ok()
			expect(def.category).to.equal(row[2])
			expect(def.value).to.equal(row[3])
		end
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
		expect(CargoRegistry.get("printer").size).to.equal("heavy")
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

	it("returns nil for an unknown id", function()
		expect(CargoRegistry.get("spaceship")).to.equal(nil)
		expect(CargoRegistry.has("spaceship")).to.equal(false)
	end)
end
