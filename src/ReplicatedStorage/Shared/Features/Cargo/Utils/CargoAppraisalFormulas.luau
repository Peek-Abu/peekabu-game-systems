--!strict
--[=[
	CargoAppraisalFormulas: what a valuable is worth (docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md
	§3.1-3.3). A valuable's base (true) value is rolled once from its catalog range, scaled by how deep it spawned and,
	rarely, by its jackpot. What it pays is base x fragile tier x grime factor; it is appraised (its "$???" revealed)
	once cleanliness first reaches APPRAISE_AT. Cleaning is an Interaction channel whose progress covers the grime that
	was left when it started (`cleanAt`). Pure.

	@class CargoAppraisalFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

type ItemDef = CargoTypes.ItemDef

local function round(value: number): number
	return math.floor(value + 0.5)
end

local CargoAppraisalFormulas = {}

--[=[
	The value multiplier for a spawn `depth` rooms from the loading bay: x1 up to the first room, DEPTH_VALUE_STEP more
	per room after it, at most DEPTH_VALUE_MAX.
]=]
function CargoAppraisalFormulas.depthMultiplier(depth: number): number
	local steps = math.max(0, depth - 1)
	return math.min(1 + CargoConstants.DEPTH_VALUE_STEP * steps, CargoConstants.DEPTH_VALUE_MAX)
end

--[=[
	Rolls a valuable spawned `depth` rooms deep: an integer in its range times the depth multiplier, times its
	jackpot's multiplier when the jackpot draw hits. Draws one integer and one number from `rng` for every kind (with or
	without a jackpot), so a seeded plan rolls the same whatever it holds. Also returns the plain value (no jackpot),
	which the map's value guarantee counts so a lucky jackpot never raises what the quota assumes.
]=]
function CargoAppraisalFormulas.roll(def: ItemDef, depth: number, rng: Random): (CargoTypes.AppraisalRoll, number)
	local rolled = rng:NextInteger(def.valueMin, def.valueMax) * CargoAppraisalFormulas.depthMultiplier(depth)
	local draw = rng:NextNumber()
	local plain = round(rolled)
	local jackpot = def.jackpot
	if jackpot ~= nil and draw < jackpot.chance then
		return { base = round(rolled * jackpot.multiplier), variant = jackpot.name }, plain
	end
	return { base = plain, variant = nil }, plain
end

--[=[
	A rolled valuable as it spawns: fully grimy, not yet appraised.
]=]
function CargoAppraisalFormulas.fresh(roll: CargoTypes.AppraisalRoll): CargoTypes.Appraisal
	return { base = roll.base, variant = roll.variant, clean = 0, appraised = false }
end

--[=[
	The share of its value a valuable `clean` (0-1) pays: GRIME_FLOOR when fully grimy, all of it when clean.
]=]
function CargoAppraisalFormulas.grimeFactor(clean: number): number
	local floor = CargoConstants.GRIME_FLOOR
	return floor + (1 - floor) * math.clamp(clean, 0, 1)
end

--[=[
	What an item pays now: `base` x its fragile tier after `impacts` (fragile kinds only) x the grime factor of `clean`,
	rounded to a whole amount.
]=]
function CargoAppraisalFormulas.value(def: ItemDef, base: number, impacts: number, clean: number): number
	local tier = 1
	if def.fragile then
		local tiers = CargoConstants.FRAGILE_TIERS
		tier = tiers[math.clamp(math.floor(impacts) + 1, 1, #tiers)]
	end
	return round(math.max(0, base) * tier * CargoAppraisalFormulas.grimeFactor(clean))
end

--[=[
	Whether a valuable `clean` is appraised: once it reaches APPRAISE_AT, and for good after.
]=]
function CargoAppraisalFormulas.isAppraised(clean: number, already: boolean): boolean
	return already or clean >= CargoConstants.APPRAISE_AT
end

--[=[
	Cleanliness after a cleaning channel that began at `start` reached `progress` (0-1): the channel cleans the grime
	that was left.
]=]
function CargoAppraisalFormulas.cleanAt(start: number, progress: number): number
	local from = math.clamp(start, 0, 1)
	return from + (1 - from) * math.clamp(progress, 0, 1)
end

--[=[
	The Gloom still on an item `clean` (0-1): its size's Gloom (CargoConstants.GLOOM_BY_SIZE) times the grime left,
	rounded. Trash carries none (docs/superpowers/specs/2026-10-16-cleanup-crew-gloom-gleam-economy-design.md §3.2).
]=]
function CargoAppraisalFormulas.gloomLeft(def: ItemDef, clean: number): number
	if not def.grimy then
		return 0
	end
	return round((CargoConstants.GLOOM_BY_SIZE[def.size] or 0) * (1 - math.clamp(clean, 0, 1)))
end

--[=[
	The Gloom a cleaning from `before` to `after` removed: the rounded Gloom left before minus after, never negative.
	Being a difference of the same rounding, the steps of one cleaning always add up to exactly the item's Gloom.
]=]
function CargoAppraisalFormulas.gloomRemoved(def: ItemDef, before: number, after: number): number
	return math.max(0, CargoAppraisalFormulas.gloomLeft(def, before) - CargoAppraisalFormulas.gloomLeft(def, after))
end

--[=[
	A valuable's shown name: its jackpot's name in front once it is appraised ("Gold-trim monitor"), else the
	catalog name, so a jackpot is a surprise.
]=]
function CargoAppraisalFormulas.displayName(def: ItemDef, variant: string?, appraised: boolean): string
	if variant ~= nil and appraised then
		return `{variant} {string.lower(def.name)}`
	end
	return def.name
end

return CargoAppraisalFormulas
