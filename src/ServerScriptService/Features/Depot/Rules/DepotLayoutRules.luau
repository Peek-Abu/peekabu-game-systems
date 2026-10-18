--!strict
--[=[
	DepotLayoutRules: is a depot layout buildable and safe to play? `validate` lists every problem: a floor
	with no area; fewer than MIN_TRUCKS or more than MAX_TRUCKS trucks; duplicate or empty truck ids; a
	capacity that is not a whole number from 1 to MAX_CAPACITY; a countdown outside MIN..MAX_COUNTDOWN; a
	truck (bed and cab) not inside the floor; two trucks closer than TRUCK_GAP; a board outside the floor, on a
	truck or on the other board; no spawn points; a spawn outside the floor or within SPAWN_CLEARANCE of a
	truck (a player would spawn straight into a queue). DepotServiceServer refuses to build a layout that
	fails. Pure.

	@class DepotLayoutRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)

type Rect = DepotTypes.Rect
type Point = DepotTypes.Point
type Truck = DepotTypes.Truck

local function inside(outer: Rect, inner: Rect, margin: number): boolean
	return inner.minX >= outer.minX + margin
		and inner.maxX <= outer.maxX - margin
		and inner.minZ >= outer.minZ + margin
		and inner.maxZ <= outer.maxZ - margin
end

-- The distance between two rectangles; 0 when they touch or overlap.
local function gap(a: Rect, b: Rect): number
	local dx = math.max(a.minX - b.maxX, b.minX - a.maxX, 0)
	local dz = math.max(a.minZ - b.maxZ, b.minZ - a.maxZ, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

-- The bed and the cab behind it (+z).
local function footprint(truck: Truck): Rect
	local bed = DepotLayoutConstants.BED_SIZE
	return {
		minX = truck.x - bed.X / 2,
		maxX = truck.x + bed.X / 2,
		minZ = truck.z - bed.Z / 2,
		maxZ = truck.z + bed.Z / 2 + DepotLayoutConstants.CAB_SIZE.Z,
	}
end

local function boardRect(point: Point): Rect
	local size = DepotLayoutConstants.BOARD_SIZE
	return {
		minX = point.x - size.X / 2,
		maxX = point.x + size.X / 2,
		minZ = point.z - size.Z / 2,
		maxZ = point.z + size.Z / 2,
	}
end

local function pointRect(point: Point): Rect
	return { minX = point.x, maxX = point.x, minZ = point.z, maxZ = point.z }
end

local DepotLayoutRules = {}

--[=[
	Every problem with `layout`; ok when there are none.
]=]
function DepotLayoutRules.validate(layout: DepotTypes.Layout): (boolean, { string })
	local errors: { string } = {}
	local floor = layout.floor
	local margin = DepotLayoutConstants.MARGIN
	if floor.minX >= floor.maxX or floor.minZ >= floor.maxZ then
		table.insert(errors, "the depot floor has no area")
	end

	local count = #layout.trucks
	local minTrucks = DepotLayoutConstants.MIN_TRUCKS
	local maxTrucks = DepotLayoutConstants.MAX_TRUCKS
	if count < minTrucks or count > maxTrucks then
		table.insert(errors, `{count} trucks; the depot needs {minTrucks}-{maxTrucks}`)
	end
	local seen: { [string]: boolean } = {}
	local maxCapacity = DepotLayoutConstants.MAX_CAPACITY
	local minCountdown = DepotLayoutConstants.MIN_COUNTDOWN
	local maxCountdown = DepotLayoutConstants.MAX_COUNTDOWN
	for _, truck in layout.trucks do
		if truck.id == "" then
			table.insert(errors, "a truck has no id")
		elseif seen[truck.id] then
			table.insert(errors, `truck "{truck.id}" is defined twice`)
		end
		seen[truck.id] = true
		local capacity = truck.capacity
		if capacity < 1 or capacity > maxCapacity or capacity ~= math.floor(capacity) then
			table.insert(errors, `truck "{truck.id}": capacity must be a whole number from 1 to {maxCapacity}`)
		end
		if truck.countdown < minCountdown or truck.countdown > maxCountdown then
			table.insert(errors, `truck "{truck.id}": countdown must be {minCountdown}-{maxCountdown} seconds`)
		end
		if not inside(floor, footprint(truck), margin) then
			table.insert(errors, `truck "{truck.id}" is not inside the floor`)
		end
	end
	for index, a in layout.trucks do
		for other = index + 1, #layout.trucks do
			local b = layout.trucks[other]
			if gap(footprint(a), footprint(b)) < DepotLayoutConstants.TRUCK_GAP then
				table.insert(
					errors,
					`trucks "{a.id}" and "{b.id}" are closer than {DepotLayoutConstants.TRUCK_GAP} studs`
				)
			end
		end
	end

	local function checkBoard(name: string, point: Point)
		local rect = boardRect(point)
		if not inside(floor, rect, margin) then
			table.insert(errors, `the {name} is not inside the floor`)
		end
		for _, truck in layout.trucks do
			if overlaps(rect, footprint(truck)) then
				table.insert(errors, `the {name} stands on truck "{truck.id}"`)
			end
		end
	end
	checkBoard("contract board", layout.contractBoard)
	checkBoard("result board", layout.resultBoard)
	if overlaps(boardRect(layout.contractBoard), boardRect(layout.resultBoard)) then
		table.insert(errors, "the contract and result boards overlap")
	end

	if #layout.spawns == 0 then
		table.insert(errors, "no spawn points")
	end
	local clearance = DepotLayoutConstants.SPAWN_CLEARANCE
	for index, point in layout.spawns do
		local rect = pointRect(point)
		if not inside(floor, rect, margin) then
			table.insert(errors, `spawn {index} is not inside the floor`)
		end
		for _, truck in layout.trucks do
			if gap(rect, footprint(truck)) < clearance then
				table.insert(errors, `spawn {index} is within {clearance} studs of truck "{truck.id}"`)
			end
		end
	end
	return #errors == 0, errors
end

return DepotLayoutRules
