--!strict
--[=[
	TrainingMapRules: reads the authored Training map (its tagged parts, as plain entries) into the plan a training run
	uses, and lists everything wrong with it. A builder restyles the map in Studio; this is what keeps it playable:
	- exactly one spawn, rest, safe box and bay box;
	- every stop (TrainingConstants.STOPS) has a start ("stop") and a zone;
	- a "piles" stop has at least one pile of a known kind, a "banked" stop at least one treasure (a valuable);
	- a stop with its own goal has a door, so the player cannot walk past it;
	- Harlow's route has at least two points with different orders (walked in order, as a loop, after a chase);
	- Harlow's scripted pass at the escape stop: his lane (at least three ordered points: in through the STAFF door,
	  past the player, out through his exit door), his one offstage spot, one staffDoor and one exitDoor;
	- every role is known, and every pile or item kind is known.

	`boxOf` turns a box part into its world-aligned bounds and `inside` tests a point.

	@class TrainingMapRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)

-- One part of the map, as read from its attributes.
export type Entry = {
	role: string,
	stop: number?,
	order: number?,
	kind: string?,
	cframe: CFrame,
	size: Vector3,
}

export type Box = { min: Vector3, max: Vector3 }

export type Spawn = { stop: number, kind: string, cframe: CFrame }

export type Plan = {
	spawn: CFrame,
	rest: Vector3,
	safe: Box,
	bay: Box,
	-- By stop number: where it starts, and its zone.
	stops: { CFrame },
	zones: { Box },
	piles: { Spawn },
	items: { Spawn },
	route: { Vector3 },
	-- Harlow's scripted pass, in order, and where he waits out of sight (facing in).
	lane: { Vector3 },
	offstage: CFrame,
}

-- Which kinds the game knows: a pile kind, any cargo id, and a valuable (a treasure, not trash).
export type Kinds = {
	pile: (kind: string) -> boolean,
	item: (kind: string) -> boolean,
	treasure: (kind: string) -> boolean,
}

local STOPS = TrainingConstants.STOPS
local SINGLES = { "spawn", "rest", "safe", "bay", "offstage", "staffDoor", "exitDoor" }

local TrainingMapRules = {}

function TrainingMapRules.boxOf(cframe: CFrame, size: Vector3): Box
	local half = size / 2
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = cframe:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
				low = low:Min(corner)
				high = high:Max(corner)
			end
		end
	end
	return { min = low, max = high }
end

function TrainingMapRules.inside(box: Box, point: Vector3): boolean
	local min, max = box.min, box.max
	return point.X >= min.X
		and point.X <= max.X
		and point.Y >= min.Y
		and point.Y <= max.Y
		and point.Z >= min.Z
		and point.Z <= max.Z
end

--[=[
	The plan read from `entries`, or nil with every problem found (each a short line naming the part or stop).
]=]
function TrainingMapRules.read(entries: { Entry }, kinds: Kinds): (Plan?, { string })
	local errors: { string } = {}
	local known: { [string]: boolean } = {}
	for _, role in TrainingConstants.ROLES do
		known[role] = true
	end
	local byRole: { [string]: { Entry } } = {}
	for _, entry in entries do
		if not known[entry.role] then
			table.insert(errors, `unknown role "{entry.role}"`)
		else
			local list = byRole[entry.role] or {}
			byRole[entry.role] = list
			table.insert(list, entry)
		end
	end
	local function all(role: string): { Entry }
		return byRole[role] or {}
	end
	local function atStop(role: string, stop: number): { Entry }
		local found = {}
		for _, entry in all(role) do
			if entry.stop == stop then
				table.insert(found, entry)
			end
		end
		return found
	end

	for _, role in SINGLES do
		local count = #all(role)
		if count ~= 1 then
			table.insert(errors, `needs exactly one {role} (found {count})`)
		end
	end

	local stops: { CFrame } = {}
	local zones: { Box } = {}
	for index, def in STOPS do
		local starts, areas = atStop("stop", index), atStop("zone", index)
		if #starts ~= 1 or #areas ~= 1 then
			table.insert(errors, `stop {index} needs one start and one zone (found {#starts} and {#areas})`)
		else
			stops[index] = starts[1].cframe
			zones[index] = TrainingMapRules.boxOf(areas[1].cframe, areas[1].size)
		end
		if def.goal == "piles" and #atStop("pile", index) == 0 then
			table.insert(errors, `stop {index} needs a Gloom pile`)
		end
		if def.goal == "banked" then
			local treasures = 0
			for _, entry in atStop("item", index) do
				if entry.kind ~= nil and kinds.treasure(entry.kind) then
					treasures += 1
				end
			end
			if treasures == 0 then
				table.insert(errors, `stop {index} needs a treasure`)
			end
		end
		if (def.goal == "piles" or def.goal == "banked") and #atStop("door", index) == 0 then
			table.insert(errors, `stop {index} needs a door`)
		end
	end

	local piles: { Spawn } = {}
	for _, entry in all("pile") do
		local kind, stop = entry.kind, entry.stop
		if kind == nil or not kinds.pile(kind) or stop == nil then
			table.insert(errors, `pile of unknown kind "{kind or "?"}" or with no stop`)
		else
			table.insert(piles, { stop = stop, kind = kind, cframe = entry.cframe })
		end
	end
	local items: { Spawn } = {}
	for _, entry in all("item") do
		local kind, stop = entry.kind, entry.stop
		if kind == nil or not kinds.item(kind) or stop == nil then
			table.insert(errors, `item of unknown kind "{kind or "?"}" or with no stop`)
		else
			table.insert(items, { stop = stop, kind = kind, cframe = entry.cframe })
		end
	end

	-- A role's points in their ORDER, naming a missing or repeated order and too few points.
	local function ordered(role: string, fewest: number): { Vector3 }
		local points = table.clone(all(role))
		table.sort(points, function(a, b)
			return (a.order or 0) < (b.order or 0)
		end)
		local list: { Vector3 } = {}
		local orders: { [number]: boolean } = {}
		for _, entry in points do
			local order = entry.order
			if order == nil or orders[order] then
				table.insert(errors, `{role} point with a missing or repeated order ({order or "?"})`)
			else
				orders[order] = true
				table.insert(list, entry.cframe.Position)
			end
		end
		if #list < fewest then
			table.insert(errors, `the {role} needs at least {fewest} points (found {#list})`)
		end
		return list
	end
	local route = ordered("route", 2)
	local lane = ordered("lane", 3)

	if #errors > 0 then
		return nil, errors
	end
	local function single(role: string): Entry
		return all(role)[1]
	end
	return {
		spawn = single("spawn").cframe,
		rest = single("rest").cframe.Position,
		safe = TrainingMapRules.boxOf(single("safe").cframe, single("safe").size),
		bay = TrainingMapRules.boxOf(single("bay").cframe, single("bay").size),
		stops = stops,
		zones = zones,
		piles = piles,
		items = items,
		route = route,
		lane = lane,
		offstage = single("offstage").cframe,
	},
		errors
end

return TrainingMapRules
