--!strict
--[=[
	OfficeLayoutMeasureHarness: measures generated offices against the size targets, so the generator's constants can
	be tuned from numbers (the spike-match plan, Task 6).

	For each seed, `run` generates the layout (OfficeLayoutGenerationUtils.generate over OfficeLayoutConstants.LAYOUT)
	and records:
	- rooms: the kit rooms (reception and server included), and pods: how many of them are desk pods;
	- area: every room's floor but the bay's, hallways included (as the generator spec's floor-area test sums it);
	- maxWalk: the longest walk in studs from the bay to any room (OfficeLayoutUtils.walkDistances, what
	  OfficeLayoutRules.checkWalk holds to the limit);
	- hideSpots: desks plus closets (OfficeLayoutRules.checkHideSpots);
	- gloom: the site's total Gloom (OfficeLootUtils.gloomOf) of the first spawn roll that meets the biggest crew's
	  contract, rolled as the generator spec's contract test does (variant A, seeds seed, seed + 1, ...).
	A seed whose generate errors, or whose rolls never meet the contract, gets ok = false and the reason.

	`format` prints one line per seed, then the means and min/max against the targets. Pure: builds no instances.

	@class OfficeLayoutMeasureHarness
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

local OfficeServer = ServerScriptService.Features.Office
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeLayoutConstants = require(OfficeServer.Data.OfficeLayoutConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeSpawnRules = require(OfficeServer.Rules.OfficeSpawnRules)
local OfficeLayoutGenerationUtils = require(OfficeServer.Utils.OfficeLayoutGenerationUtils)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeLootUtils = require(OfficeServer.Utils.OfficeLootUtils)
local OfficeSpawnUtils = require(OfficeServer.Utils.OfficeSpawnUtils)

-- The floor-area band around TARGET_FLOOR_AREA, and the least share of kit rooms that are desk pods.
local AREA_BAND = 0.3
local PODS_SHARE_MIN = 0.25

export type Row = {
	seed: number,
	rooms: number,
	pods: number,
	area: number,
	maxWalk: number,
	hideSpots: number,
	gloom: number,
	ok: boolean,
	error: string?,
}

export type Generate = (base: OfficeTypes.Layout, seed: number) -> OfficeTypes.Layout

local OfficeLayoutMeasureHarness = {}

-- The total Gloom of the first roll that meets the biggest crew's contract, or the last roll's and the reason.
local function contractGloom(layout: OfficeTypes.Layout, seed: number): (number, string?)
	local contract = ShiftConstants.QUOTA_BY_CREW[#ShiftConstants.QUOTA_BY_CREW]
	local gloom, failure = 0, nil
	for attempt = 0, OfficeConstants.ROLL_ATTEMPTS - 1 do
		local plan = OfficeSpawnUtils.roll(layout, {
			quota = contract,
			variant = "A",
			dirtyRooms = OfficeConstants.DIRTY_ROOMS,
			pilesPerRoom = OfficeConstants.PILES_PER_ROOM,
			valuables = OfficeConstants.VALUABLES,
		}, Random.new(seed + attempt))
		gloom = OfficeLootUtils.gloomOf(plan).total
		local ok, reason = OfficeSpawnRules.check(plan, layout, contract)
		if ok then
			return gloom, nil
		end
		failure = reason
	end
	return gloom, `contract: {failure or "?"}`
end

local function measure(layout: OfficeTypes.Layout, seed: number): Row
	local rooms, pods, area = 0, 0, 0
	for _, room in layout.rooms do
		if room.id ~= "bay" then
			area += (room.maxX - room.minX) * (room.maxZ - room.minZ)
		end
		if room.kit ~= nil then
			rooms += 1
			pods += if room.roomType == "pods" then 1 else 0
		end
	end
	local maxWalk = 0
	for _, distance in OfficeLayoutUtils.walkDistances(layout) do
		maxWalk = math.max(maxWalk, distance)
	end
	local hideSpots = #OfficeLayoutUtils.markersOf(layout, "desk") + #OfficeLayoutUtils.markersOf(layout, "closet")
	local gloom, failure = contractGloom(layout, seed)
	return {
		seed = seed,
		rooms = rooms,
		pods = pods,
		area = area,
		maxWalk = maxWalk,
		hideSpots = hideSpots,
		gloom = gloom,
		ok = failure == nil,
		error = failure,
	}
end

--[=[
	Measures each seed's generated office. `generate` defaults to OfficeLayoutGenerationUtils.generate (a spec passes
	one that errors).
]=]
function OfficeLayoutMeasureHarness.run(seeds: { number }, generate: Generate?): { Row }
	local build: Generate = generate or OfficeLayoutGenerationUtils.generate
	local rows: { Row } = {}
	for _, seed in seeds do
		local ok, result = pcall(build, OfficeLayoutConstants.LAYOUT, seed)
		if ok then
			table.insert(rows, measure(result, seed))
		else
			table.insert(rows, {
				seed = seed,
				rooms = 0,
				pods = 0,
				area = 0,
				maxWalk = 0,
				hideSpots = 0,
				gloom = 0,
				ok = false,
				error = tostring(result),
			})
		end
	end
	return rows
end

type Stat = { mean: number, min: number, max: number }

local function stat(rows: { Row }, read: (row: Row) -> number): Stat
	local sum, low, high = 0, math.huge, -math.huge
	for _, row in rows do
		local value = read(row)
		sum += value
		low, high = math.min(low, value), math.max(high, value)
	end
	if #rows == 0 then
		return { mean = 0, min = 0, max = 0 }
	end
	return { mean = sum / #rows, min = low, max = high }
end

-- The nearest whole number (string.format's %d refuses a fraction).
local function round(value: number): number
	return math.floor(value + 0.5)
end

local function verdict(pass: boolean): string
	return if pass then "OK" else "MISS"
end

--[=[
	One line per seed, then the means and min/max of the seeds that generated, against the targets: floor area within
	AREA_BAND of TARGET_FLOOR_AREA (mean), every walk within WALK_SPEED * MAX_WALK_SECONDS, every seed at
	HIDE_SPOTS_MIN hide spots or more, and desk pods at least PODS_SHARE_MIN of all kit rooms.
]=]
function OfficeLayoutMeasureHarness.format(rows: { Row }): string
	local lines: { string } = {}
	local measured: { Row } = {}
	local failed = 0
	for _, row in rows do
		local line = string.format(
			"seed %d: rooms %d (pods %d), area %d, walk %d (%.1f s), hide %d, gloom %d",
			row.seed,
			row.rooms,
			row.pods,
			round(row.area),
			round(row.maxWalk),
			row.maxWalk / OfficeConstants.WALK_SPEED,
			row.hideSpots,
			round(row.gloom)
		)
		if not row.ok then
			failed += 1
			line ..= ` FAILED: {row.error or "?"}`
		end
		if row.area > 0 then
			table.insert(measured, row)
		end
		table.insert(lines, line)
	end
	local target = OfficeConstants.TARGET_FLOOR_AREA
	local walkLimit = OfficeConstants.WALK_SPEED * OfficeConstants.MAX_WALK_SECONDS
	local area = stat(measured, function(row)
		return row.area
	end)
	local walk = stat(measured, function(row)
		return row.maxWalk
	end)
	local hide = stat(measured, function(row)
		return row.hideSpots
	end)
	local rooms = stat(measured, function(row)
		return row.rooms
	end)
	local gloom = stat(measured, function(row)
		return row.gloom
	end)
	local pods = stat(measured, function(row)
		return row.pods
	end)
	local share = if rooms.mean > 0 then pods.mean / rooms.mean else 0
	table.insert(lines, `{#rows} seeds, {failed} failed`)
	table.insert(
		lines,
		string.format(
			"area mean %d (min %d, max %d), target %d +/-%d%% [%d-%d]: %s",
			round(area.mean),
			round(area.min),
			round(area.max),
			target,
			round(AREA_BAND * 100),
			round(target * (1 - AREA_BAND)),
			round(target * (1 + AREA_BAND)),
			verdict(math.abs(area.mean - target) <= target * AREA_BAND)
		)
	)
	table.insert(
		lines,
		string.format(
			"walk mean %d (min %d, max %d), limit %d: %s",
			round(walk.mean),
			round(walk.min),
			round(walk.max),
			round(walkLimit),
			verdict(walk.max <= walkLimit)
		)
	)
	table.insert(
		lines,
		string.format(
			"hide mean %.1f (min %d, max %d), least %d: %s",
			hide.mean,
			round(hide.min),
			round(hide.max),
			OfficeConstants.HIDE_SPOTS_MIN,
			verdict(hide.min >= OfficeConstants.HIDE_SPOTS_MIN)
		)
	)
	table.insert(
		lines,
		string.format(
			"rooms mean %.1f (min %d, max %d); pods share %d%%, least %d%%: %s",
			rooms.mean,
			round(rooms.min),
			round(rooms.max),
			round(share * 100),
			round(PODS_SHARE_MIN * 100),
			verdict(share >= PODS_SHARE_MIN)
		)
	)
	table.insert(
		lines,
		string.format("gloom mean %d (min %d, max %d)", round(gloom.mean), round(gloom.min), round(gloom.max))
	)
	return table.concat(lines, "\n")
end

return OfficeLayoutMeasureHarness
