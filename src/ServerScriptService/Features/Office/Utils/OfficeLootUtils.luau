--!strict
--[=[
	OfficeLootUtils: the map's loot economy (docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md §3.5).
	OfficeSpawnUtils places things; this says what they are worth and how many piles bury something:

	- `buried`: one BURY_CHANCE draw per pile, in order; the hits, capped at `room` (what the valuables budget leaves);
	- `valueOf`: a plan's valuables (open, buried and in desks) at their plain base (a jackpot's multiplier taken off, so
	  luck never raises what the quota assumes), its trash (floor, desks, and one dust bag per full canister of piles),
	  and both at full and at average cleanliness (LOOT_AVERAGE_CLEAN);
	- `shortfall`: whether the quota would need more than LOOT_QUOTA_SHARE_MAX of the average value (the roll then tops
	  the map up, and OfficeSpawnRules refuses a plan still short).

	Pure.

	@class OfficeLootUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local CargoAppraisalFormulas = require(ReplicatedStorage.Shared.Features.Cargo.Utils.CargoAppraisalFormulas)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

export type PlanValue = {
	-- How many valuables the plan offers.
	valuables: number,
	-- Trash value: floor and desk trash plus the piles' dust bags.
	trash: number,
	-- Everything at full cleanliness (valuables at their plain base).
	full: number,
	-- Everything at average cleanliness (LOOT_AVERAGE_CLEAN).
	average: number,
}

local OfficeLootUtils = {}

--[=[
	The trash the dust bags of `pileCount` piles come to: one bag per full canister.
]=]
function OfficeLootUtils.pileTrash(pileCount: number): number
	local dustBag = CargoRegistry.get(VacuumConstants.DUST_BAG_KIND)
	local bags = math.floor(pileCount / VacuumConstants.CANISTER_CAPACITY)
	return bags * (if dustBag ~= nil then dustBag.value else 0)
end

--[=[
	Which of `pileCount` piles bury something: one BURY_CHANCE draw per pile (all drawn, so `rng` is used alike
	whatever the cap), the indices of the hits in order, at most `room` of them.
]=]
function OfficeLootUtils.buried(pileCount: number, room: number, rng: Random): { number }
	local hits: { number } = {}
	for index = 1, pileCount do
		if rng:NextNumber() < OfficeConstants.BURY_CHANCE and #hits < room then
			table.insert(hits, index)
		end
	end
	return hits
end

-- A valuable's plain base: its rolled base without any jackpot multiplier; the catalog's reference value unrolled.
local function plainOf(def: CargoTypes.ItemDef, roll: CargoTypes.AppraisalRoll?): number
	if roll == nil then
		return def.value
	end
	local jackpot = def.jackpot
	if roll.variant ~= nil and jackpot ~= nil then
		return roll.base / jackpot.multiplier
	end
	return roll.base
end

--[=[
	What `plan` offers (see PlanValue).
]=]
function OfficeLootUtils.valueOf(plan: OfficeTypes.SpawnPlan): PlanValue
	local valuables, plain, trash = 0, 0, OfficeLootUtils.pileTrash(#plan.piles)
	local function add(kind: string?, roll: CargoTypes.AppraisalRoll?)
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		if def == nil then
			return
		end
		if def.grimy then
			valuables += 1
			plain += plainOf(def, roll)
		else
			trash += def.value
		end
	end
	for _, item in plan.items do
		add(item.kind, item.appraisal)
	end
	for _, pile in plan.piles do
		add(pile.hides, pile.appraisal)
	end
	for _, search in plan.searchables do
		add(search.kind, search.appraisal)
	end
	return {
		valuables = valuables,
		trash = trash,
		full = plain + trash,
		average = plain * CargoAppraisalFormulas.grimeFactor(OfficeConstants.LOOT_AVERAGE_CLEAN) + trash,
	}
end

--[=[
	Whether `plan` is too poor for `quota`: the quota needs more than LOOT_QUOTA_SHARE_MAX of its average value.
]=]
function OfficeLootUtils.shortfall(plan: OfficeTypes.SpawnPlan, quota: number): boolean
	return OfficeLootUtils.valueOf(plan).average * OfficeConstants.LOOT_QUOTA_SHARE_MAX < quota
end

return OfficeLootUtils
