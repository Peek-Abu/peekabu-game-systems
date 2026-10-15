--!strict
--[=[
	CargoRegistry: the cargo catalog (Cleanup Crew spec §4 table): eleven items found in the office plus the
	dust bag the vacuum makes. Built here at load and frozen; `ids()` is sorted so a roll that walks the
	catalog picks the same items for the same seed.

	Trash has a fixed price. A valuable (salvage) has a base RANGE, rolled once per shift and scaled by depth
	(CargoAppraisalFormulas), an optional rare jackpot variant, and spawns grimy; its `value` is the range's middle,
	a reference only (docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md §3.1: about 3x the old
	catalog once depth is applied, the greed targets about 4x).

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
	-- A valuable's base range (salvage only); absent = the fixed `value`.
	range: { min: number, max: number }?,
	jackpot: CargoTypes.Jackpot?,
	-- Fits under a dust pile (buried loot): small, non-greed valuables.
	buriable: boolean?,
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
	size: CargoTypes.Size,
	color: Color3,
	traits: Traits,
	fixed: number?
)
	assert(items[id] == nil, `cargo item "{id}" is defined twice`)
	local range = traits.range
	assert((range == nil) ~= (fixed == nil), `cargo item "{id}": give a fixed value or a range, not both`)
	local valueMin = if range ~= nil then range.min else fixed or 0
	local valueMax = if range ~= nil then range.max else fixed or 0
	assert(valueMin > 0 and valueMax >= valueMin, `cargo item "{id}": the value range must be positive`)
	assert((category == "salvage") == (range ~= nil), `cargo item "{id}": valuables have a range, trash a fixed value`)
	local jackpot = traits.jackpot
	if jackpot ~= nil then
		assert(category == "salvage", `cargo item "{id}": only valuables have a jackpot`)
		assert(jackpot.chance > 0 and jackpot.chance < 1, `cargo item "{id}": jackpot chance must be in (0, 1)`)
		assert(jackpot.multiplier > 1, `cargo item "{id}": jackpot multiplier must be above 1`)
	end
	local value = math.floor((valueMin + valueMax) / 2 + 0.5)
	local spawnWeight = traits.spawnWeight or 0
	local deskWeight = traits.deskWeight or 0
	assert(spawnWeight >= 0 and deskWeight >= 0, `cargo item "{id}": weights must not be negative`)
	local def: ItemDef = {
		id = id,
		name = name,
		category = category,
		value = value,
		valueMin = valueMin,
		valueMax = valueMax,
		jackpot = if jackpot ~= nil then table.freeze(table.clone(jackpot)) else nil,
		grimy = category == "salvage",
		buriable = traits.buriable == true,
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

-- Trash: a fixed price, counted toward the quota (no Recovery pay).
define("rubbishBag", "Rubbish bag", "trash", "light", Color3.fromRGB(40, 40, 45), {
	throwable = true,
	spawnWeight = 3,
	deskWeight = 2,
}, 10)
define("dustBag", "Dust bag", "trash", "light", Color3.fromRGB(150, 135, 110), { throwable = true }, 15)
define("recyclingBox", "Recycling box", "trash", "light", Color3.fromRGB(60, 120, 200), {
	spills = true,
	spawnWeight = 2,
}, 15)
define("bottleBag", "Bottle bag", "trash", "light", Color3.fromRGB(70, 160, 90), {
	rattly = true,
	spawnWeight = 2,
	deskWeight = 1,
}, 15)

-- Valuables (Recoverable Assets): a base range before depth, grimy until vacuumed.
define("officePlant", "Office plant", "salvage", "medium", Color3.fromRGB(50, 140, 60), {
	blocksView = true,
	spawnWeight = 3,
	range = { min = 45, max = 90 },
	buriable = true,
})
define("plaque", "Employee of the Month plaque", "salvage", "tiny", Color3.fromRGB(190, 150, 70), {
	spawnWeight = 2,
	deskWeight = 3,
	range = { min = 50, max = 100 },
	jackpot = { name = "Solid brass", chance = 0.08, multiplier = 2.5 },
	buriable = true,
})
define("monitor", "Monitor", "salvage", "medium", Color3.fromRGB(30, 30, 35), {
	fragile = true,
	spawnWeight = 3,
	range = { min = 40, max = 120 },
	jackpot = { name = "Gold-trim", chance = 0.1, multiplier = 2.5 },
	buriable = true,
})
define("waterJug", "Water cooler jug", "salvage", "heavy", Color3.fromRGB(120, 180, 230), {
	splashes = true,
	spawnWeight = 2,
	range = { min = 60, max = 110 },
})
define("coffeeMachine", "Coffee machine", "salvage", "heavy", Color3.fromRGB(110, 70, 50), {
	rattly = true,
	spawnWeight = 1,
	range = { min = 120, max = 200 },
	jackpot = { name = "Chrome espresso", chance = 0.08, multiplier = 2 },
})
define("fishTank", "Fish tank", "salvage", "heavy", Color3.fromRGB(80, 200, 220), {
	fragile = true,
	rattly = true,
	greed = true,
	range = { min = 200, max = 320 },
})
define("goldenStapler", "Golden stapler", "salvage", "tiny", Color3.fromRGB(255, 200, 40), {
	hidden = true,
	greed = true,
	range = { min = 180, max = 300 },
	jackpot = { name = "24-karat", chance = 0.15, multiplier = 2 },
})
define("filingCabinet", "Filing cabinet on cart", "salvage", "bulky", Color3.fromRGB(120, 125, 135), {
	greed = true,
	range = { min = 260, max = 420 },
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
