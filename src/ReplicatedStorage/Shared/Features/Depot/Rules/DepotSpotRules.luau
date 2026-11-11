--!strict
--[=[
	DepotSpotRules: the hub spots' decisions (DepotSpotConstants), pure.

	- `spots`: every spot; `spotOf`: which spot an Interaction kind is (nil for any other kind).
	- `open`: what a use of a spot opens, checked on the server: a standee only for a real employee
	  (EmployeeRegistry); `decode` checks the same on the client when the packet arrives.
	- `nextStation`: the radio's next station (wraps; a bad index starts over).
	- `bellReady`: whether a bell has rested its cooldown.
	- `bellSwing`: the bell's swing after a ring; `noteRate`: the radio's music notes on a station.
	- `driveGap`, `road`, `roadLength`, `along`: the delivery truck outside: the wait before its next pass, the road
	  its tagged parts make (ordered; needs two at least, whole and unique orders), and where it is a distance down it.

	@class DepotSpotRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

export type Spot = DepotSpotConstants.Spot

export type Opened = {
	spot: Spot,
	-- The standee's employee; "" for every other spot.
	employee: string,
}

export type RoadMarker = {
	order: unknown,
	position: Vector3,
}

-- Spot by Interaction kind, and by its own name (the packet's spot).
local BY_KIND: { [string]: Spot } = {}
local BY_NAME: { [string]: Spot } = {}
-- Every spot, in one list (iterated here: a table's keys come back as plain strings).
local SPOTS: { Spot } = { "shop", "standee", "coffee", "crew", "rank", "radio", "bell" }
for _, spot: Spot in SPOTS do
	BY_KIND[DepotSpotConstants.KINDS[spot]] = spot
	BY_NAME[spot] = spot
end

local DepotSpotRules = {}

-- Every spot (the server registers and answers each one's kind).
function DepotSpotRules.spots(): { Spot }
	return table.clone(SPOTS)
end

function DepotSpotRules.spotOf(kind: string): Spot?
	return BY_KIND[kind]
end

function DepotSpotRules.open(spot: Spot, employee: unknown): Opened?
	if spot == "standee" then
		if type(employee) ~= "string" or EmployeeRegistry.get(employee) == nil then
			return nil
		end
		return { spot = spot, employee = employee }
	end
	return { spot = spot, employee = "" }
end

function DepotSpotRules.decode(value: { spot: string, employee: string }): Opened?
	local spot: Spot? = BY_NAME[value.spot]
	if spot == nil then
		return nil
	end
	return DepotSpotRules.open(spot, if spot == "standee" then value.employee else nil)
end

function DepotSpotRules.nextStation(index: number): number
	local count = #DepotSpotConstants.STATIONS
	if index < 1 or index >= count or index ~= math.floor(index) then
		return 1
	end
	return index + 1
end

function DepotSpotRules.bellReady(lastAt: number?, now: number): boolean
	return lastAt == nil or now - lastAt >= DepotSpotConstants.BELL_COOLDOWN
end

function DepotSpotRules.driveGap(roll: number): number
	local drive = DepotSpotConstants.DRIVE_BY
	local t = math.clamp(roll, 0, 1)
	return drive.MIN_GAP + (drive.MAX_GAP - drive.MIN_GAP) * t
end

function DepotSpotRules.road(markers: { RoadMarker }): { Vector3 }?
	local byOrder: { [number]: Vector3? } = {}
	local count = 0
	for _, marker in markers do
		local order = marker.order
		if type(order) ~= "number" or order ~= math.floor(order) or order < 1 or byOrder[order] ~= nil then
			return nil
		end
		byOrder[order] = marker.position
		count += 1
	end
	if count < 2 then
		return nil
	end
	local points: { Vector3 } = {}
	for index = 1, count do
		local point = byOrder[index]
		if point == nil then
			return nil
		end
		table.insert(points, point)
	end
	return points
end

function DepotSpotRules.roadLength(road: { Vector3 }): number
	local total = 0
	for index = 2, #road do
		total += (road[index] - road[index - 1]).Magnitude
	end
	return total
end

-- The point `distance` studs down the road and the heading of the leg it is on (the last point past the end).
function DepotSpotRules.along(road: { Vector3 }, distance: number): (Vector3, Vector3)
	local left = math.max(distance, 0)
	for index = 2, #road do
		local a, b = road[index - 1], road[index]
		local leg = b - a
		local length = leg.Magnitude
		if length > 0 then
			local heading = leg / length
			if left <= length then
				return a + heading * left, heading
			end
			left -= length
		end
	end
	local last = road[#road]
	local before = road[#road - 1] or last
	local leg = last - before
	return last, if leg.Magnitude > 0 then leg.Unit else Vector3.new(0, 0, 1)
end

-- The bell's swing (degrees) `t` seconds after it rang: a damped sine, still at the start and stopped at the end.
function DepotSpotRules.bellSwing(t: number): number
	local swing = DepotSpotConstants.BELL_SWING
	if t <= 0 or t >= swing.SECONDS then
		return 0
	end
	return swing.DEGREES * math.exp(-swing.DAMPING * t) * math.sin(math.pi * 2 * swing.FREQUENCY * t)
end

-- Music notes a second from the radio on this station (none on a quiet one).
function DepotSpotRules.noteRate(station: DepotSpotConstants.Station): number
	return if station.track == nil then 0 else DepotSpotConstants.RADIO_NOTES.RATE
end

return DepotSpotRules
