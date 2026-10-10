--!strict
--[=[
	CargoRegistry: the cargo catalog (Cleanup Crew spec §4 table): twelve items found in the office plus the
	dust bag the vacuum makes. Built here at load and frozen; `ids()` is sorted so a roll that walks the
	catalog picks the same items for the same seed.

	Every number is a tuning hypothesis. spawnWeight / deskWeight are this plan's hypotheses for how often
	an item is rolled on the open floor / into a desk; greed targets are placed by the roll itself.

	@class CargoRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

type ItemDef = CargoTypes.ItemDef

-- The optional traits; anything absent is false (or 0 for weights).
type Traits = {
	throwable: boolean?,
	fragile: boolean?,
	rattly: boolean?,
	spills: boolean?,
	splashes: boolean?,
	blocksView: boolean?,
	hidden: boolean?,
	greed: boolean?,
	spawnWeight: number?,
	deskWeight: number?,
}

local PART_SIZE: { [string]: Vector3 } = {
	tiny = Vector3.new(1, 0.4, 0.8),
	light = Vector3.new(2, 2, 2),
	medium = Vector3.new(2.5, 2.5, 2.5),
	heavy = Vector3.new(3, 3, 3),
	bulky = Vector3.new(3, 5, 3.5),
}

local items: { [string]: ItemDef } = {}

local function define(
	id: string,
	name: string,
	category: CargoTypes.Category,
	value: number,
	size: CargoTypes.Size,
	color: Color3,
	traits: Traits
)
	assert(items[id] == nil, `cargo item "{id}" is defined twice`)
	assert(value > 0, `cargo item "{id}": value must be positive`)
	local spawnWeight = traits.spawnWeight or 0
	local deskWeight = traits.deskWeight or 0
	assert(spawnWeight >= 0 and deskWeight >= 0, `cargo item "{id}": weights must not be negative`)
	local def: ItemDef = {
		id = id,
		name = name,
		category = category,
		value = value,
		size = size,
		throwable = traits.throwable == true,
		fragile = traits.fragile == true,
		rattly = traits.rattly == true,
		spills = traits.spills == true,
		splashes = traits.splashes == true,
		blocksView = traits.blocksView == true,
		hidden = traits.hidden == true,
		greed = traits.greed == true,
		spawnWeight = spawnWeight,
		deskWeight = deskWeight,
		partSize = PART_SIZE[size],
		color = color,
	}
	items[id] = table.freeze(def)
end

-- Trash: clearance.
define("rubbishBag", "Rubbish bag", "trash", 10, "light", Color3.fromRGB(40, 40, 45), {
	throwable = true,
	spawnWeight = 3,
	deskWeight = 2,
})
define("dustBag", "Dust bag", "trash", 15, "light", Color3.fromRGB(150, 135, 110), { throwable = true })
define("recyclingBox", "Recycling box", "trash", 15, "light", Color3.fromRGB(60, 120, 200), {
	spills = true,
	spawnWeight = 2,
})
define("bottleBag", "Bottle bag", "trash", 15, "light", Color3.fromRGB(70, 160, 90), {
	rattly = true,
	spawnWeight = 2,
	deskWeight = 1,
})

-- Salvage: bonus.
define("officePlant", "Office plant", "salvage", 20, "medium", Color3.fromRGB(50, 140, 60), {
	blocksView = true,
	spawnWeight = 3,
})
define("plaque", "Employee of the Month plaque", "salvage", 25, "tiny", Color3.fromRGB(190, 150, 70), {
	spawnWeight = 2,
	deskWeight = 3,
})
define("monitor", "Monitor", "salvage", 30, "medium", Color3.fromRGB(30, 30, 35), { fragile = true, spawnWeight = 3 })
define("waterJug", "Water cooler jug", "salvage", 30, "heavy", Color3.fromRGB(120, 180, 230), {
	splashes = true,
	spawnWeight = 2,
})
define("printer", "Printer", "salvage", 40, "heavy", Color3.fromRGB(210, 210, 200), { spawnWeight = 2 })
define("coffeeMachine", "Coffee machine", "salvage", 50, "heavy", Color3.fromRGB(110, 70, 50), {
	rattly = true,
	spawnWeight = 1,
})
define("fishTank", "Fish tank", "salvage", 70, "heavy", Color3.fromRGB(80, 200, 220), {
	fragile = true,
	rattly = true,
	greed = true,
})
define("goldenStapler", "Golden stapler", "salvage", 80, "tiny", Color3.fromRGB(255, 200, 40), {
	hidden = true,
	greed = true,
})
define("filingCabinet", "Filing cabinet on cart", "salvage", 120, "bulky", Color3.fromRGB(120, 125, 135), {
	greed = true,
})

local sortedIds: { string } = {}
local sortedGreed: { string } = {}
for id, def in items do
	table.insert(sortedIds, id)
	if def.greed then
		table.insert(sortedGreed, id)
	end
end
table.sort(sortedIds)
table.sort(sortedGreed)
table.freeze(sortedIds)
table.freeze(sortedGreed)

local CargoRegistry = {}

function CargoRegistry.get(id: string): ItemDef?
	return items[id]
end

function CargoRegistry.has(id: string): boolean
	return items[id] ~= nil
end

-- Every id, sorted (frozen).
function CargoRegistry.ids(): { string }
	return sortedIds
end

-- The greed targets' ids, sorted (frozen).
function CargoRegistry.greedIds(): { string }
	return sortedGreed
end

return CargoRegistry
