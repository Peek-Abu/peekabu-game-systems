--!strict
--[=[
	OfficeLootUtils: the map's loot economy (docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md §3.5).
	OfficeSpawnUtils places things; this says what they are worth and how many piles bury something:

	- `buried`: one BURY_CHANCE draw per pile, in order; the hits, capped at `room` (what the valuables budget leaves);
	- `gloomOf`: the site's Gloom (docs/superpowers/specs/2026-10-16-cleanup-crew-gloom-gleam-economy-design.md §3):
	  every pile's VacuumConstants.PILE_GLOOM plus every valuable's grime at full grime (CargoAppraisalFormulas.gloomLeft:
	  its size's Gloom);
	- `valueOf`: a plan's valuables (open, buried and in desks) at their plain base (a jackpot's multiplier taken off),
	  at full and at average cleanliness (LOOT_AVERAGE_CLEAN). Trash is never rolled and is worth nothing;
	- `shortfall`: whether the contract would need more than CONTRACT_SHARE_MAX of the site's Gloom (the roll then tops
	  the map up with piles, and OfficeSpawnRules refuses a plan still short).

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
	-- The valuables at full cleanliness (at their plain base).
	full: number,
	-- The valuables at average cleanliness (LOOT_AVERAGE_CLEAN).
	average: number,
}

export type PlanGloom = {
	-- The piles' Gloom.
	dust: number,
	-- The valuables' grime, at full grime.
	grime: number,
	-- Both: the site's Gloom, which the contract is a share of.
	total: number,
}

local OfficeLootUtils = {}

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

-- Calls `visit` with every valuable `plan` offers (open, buried and in desks) and its roll.
local function eachValuable(plan: OfficeTypes.SpawnPlan, visit: (CargoTypes.ItemDef, CargoTypes.AppraisalRoll?) -> ())
	local function add(kind: string?, roll: CargoTypes.AppraisalRoll?)
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		if def ~= nil and def.grimy then
			visit(def, roll)
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
end

--[=[
	What `plan` offers (see PlanValue).
]=]
function OfficeLootUtils.valueOf(plan: OfficeTypes.SpawnPlan): PlanValue
	local valuables, plain = 0, 0
	eachValuable(plan, function(def, roll)
		valuables += 1
		plain += plainOf(def, roll)
	end)
	return {
		valuables = valuables,
		full = plain,
		average = plain * CargoAppraisalFormulas.grimeFactor(OfficeConstants.LOOT_AVERAGE_CLEAN),
	}
end

--[=[
	The site's Gloom (see PlanGloom): every valuable spawns fully grimy.
]=]
function OfficeLootUtils.gloomOf(plan: OfficeTypes.SpawnPlan): PlanGloom
	local dust = #plan.piles * VacuumConstants.PILE_GLOOM
	local grime = 0
	eachValuable(plan, function(def)
		grime += CargoAppraisalFormulas.gloomLeft(def, 0)
	end)
	return { dust = dust, grime = grime, total = dust + grime }
end

--[=[
	Whether `plan` is too thin for `contract`: the contract needs more than CONTRACT_SHARE_MAX of the site's Gloom.
]=]
function OfficeLootUtils.shortfall(plan: OfficeTypes.SpawnPlan, contract: number): boolean
	return OfficeLootUtils.gloomOf(plan).total * OfficeConstants.CONTRACT_SHARE_MAX < contract
end

return OfficeLootUtils
