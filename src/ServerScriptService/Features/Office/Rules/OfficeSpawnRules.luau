--!strict
--[=[
	OfficeSpawnRules: does one shift's spawn plan keep the spec's promises (§4 "Spawn guarantees")? The quota needs
	no more than LOOT_QUOTA_SHARE_MAX of the map's value at average cleanliness (OfficeLootUtils, docs/superpowers/
	specs/2026-10-15-cleanup-crew-loot-loop-design.md §3.5); one greed target sits in a deep room; no marker holds
	two things; loot sits on furniture it belongs on. Pure.

	@class OfficeSpawnRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeLootUtils = require(OfficeServer.Utils.OfficeLootUtils)

type SpawnPlan = OfficeTypes.SpawnPlan

local OfficeSpawnRules = {}

-- Loot that belongs on furniture, by surface marker kind: appliances live on kitchen counters,
-- meeting-table monitors, plaques and the small desk valuables (mug, clock, snow globe) on tables, plaques,
-- clocks and snow globes on cabinet tops instead of the floor.
-- Anything absent here sits on the floor; `check` refuses the rest.
local SURFACE_KINDS: { [string]: { string } } = {
	counter = { "coffeeMachine", "waterJug", "fishTank" },
	table = { "plaque", "monitor", "coffeeMachine", "waterJug", "coffeeMug", "deskClock", "snowGlobe" },
	cabinet = { "plaque", "deskClock", "snowGlobe" },
}

-- Canonical preference order for items allowed on several surfaces.
local SURFACE_ORDER: { string } = { "counter", "table", "cabinet" }

--[=[
	Untouched appliance dressing requires a top. Search reveals and dropped cargo use their separate floor policy.
]=]
function OfficeSpawnRules.requiresSurface(itemId: string): boolean
	return itemId == "coffeeMachine" or itemId == "waterJug"
end

function OfficeSpawnRules.surfaceKinds(): { [string]: { string } }
	return SURFACE_KINDS
end

--[=[
	The surface marker kinds `itemId` may sit on, in preference order; empty for floor loot.
]=]
function OfficeSpawnRules.surfaceKindsFor(itemId: string): { string }
	local kinds: { string } = {}
	for _, kind in SURFACE_ORDER do
		if table.find(SURFACE_KINDS[kind], itemId) ~= nil then
			table.insert(kinds, kind)
		end
	end
	return kinds
end

--[=[
	Ok when `plan` meets every guarantee for `quota`; otherwise the first broken one.
]=]
function OfficeSpawnRules.check(plan: SpawnPlan, layout: OfficeTypes.Layout, quota: number): (boolean, string?)
	local used: { [string]: boolean } = {}
	local markers: { string } = {}
	for _, pile in plan.piles do
		table.insert(markers, pile.marker)
	end
	for _, item in plan.items do
		if CargoRegistry.get(item.kind) == nil then
			return false, `unknown cargo "{item.kind}"`
		end
		table.insert(markers, item.marker)
	end
	for _, item in plan.items do
		local spot = OfficeLayoutUtils.marker(layout, item.marker)
		if spot ~= nil and spot.kind == "item" and OfficeSpawnRules.requiresSurface(item.kind) then
			return false, `"{item.kind}" requires a furniture surface`
		end
		if spot ~= nil and OfficeLayoutUtils.surfaceTopY(spot.kind) ~= nil then
			local allowed = OfficeSpawnRules.surfaceKinds()[spot.kind]
			if allowed == nil or table.find(allowed, item.kind) == nil then
				return false, `"{item.kind}" does not belong on a {spot.kind}`
			end
		end
	end
	for _, marker in markers do
		if used[marker] then
			return false, `marker "{marker}" is used twice`
		end
		used[marker] = true
	end

	if OfficeLootUtils.shortfall(plan, quota) then
		local have = math.floor(OfficeLootUtils.valueOf(plan).average + 0.5)
		local need = math.ceil(quota / OfficeConstants.LOOT_QUOTA_SHARE_MAX)
		return false, `only {have} of a needed {need} value for a quota of {quota}`
	end

	local greed = plan.greed
	if greed == nil then
		return false, "no greed target"
	end
	local def = CargoRegistry.get(greed.kind)
	if def == nil or not def.greed then
		return false, `"{greed.kind}" is not a greed target`
	end
	local marker = OfficeLayoutUtils.marker(layout, greed.marker)
	local depths = OfficeLayoutUtils.depths(layout)
	if marker == nil or (depths[marker.room] or 0) < OfficeConstants.DEEP_DEPTH then
		return false, "the greed target is not placed deep"
	end
	return true, nil
end

return OfficeSpawnRules
