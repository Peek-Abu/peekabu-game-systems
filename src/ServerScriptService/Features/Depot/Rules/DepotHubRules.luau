--!strict
--[=[
	DepotHubRules: where the depot's gameplay pieces go, as one plan the build reads, from either source.

	- `plan`: an authored hub's markers (a Studio-built `DepotHub` model; DepotHubSystem reads its tagged parts into
	  markers). Trucks are numbered 1..N (MIN_TRUCKS..MAX_TRUCKS, no gaps or repeats) and take default seats and
	  countdown; at least one spawn; the contract and result boards are required, the crew board, time clock and daily
	  sheet optional, each at most once. Returns nil and every problem when the hub is not playable; `check` throws them as one message instead.
	- `fromLayout`: the code-built graybox (DepotLayoutConstants.LAYOUT at ORIGIN) as the same plan, every piece where
	  the graybox always put it.
	- `inside`: whether a world point is inside a plan's bounds (the timecard's "in the depot" check).

	Every CFrame in a plan stands on the floor. A truck's faces the way its ramp points (its cab is behind, +Z); a
	board's faces its readers; a spawn's faces the way the player looks. Pure.

	@class DepotHubRules
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)

export type BoardKind = "contract" | "result" | "crew" | "clock" | "daily"

export type Marker = {
	kind: "truck" | "spawn" | "board",
	cframe: CFrame,
	-- Trucks: the number painted on the bay (1-based), optional seats and countdown.
	truck: number?,
	capacity: number?,
	countdown: number?,
	-- Boards: which board.
	board: string?,
}

export type PlanTruck = {
	id: string,
	index: number,
	capacity: number,
	countdown: number,
	cframe: CFrame,
}

export type Bounds = {
	cframe: CFrame,
	size: Vector3,
}

export type Plan = {
	trucks: { PlanTruck },
	spawns: { CFrame },
	boards: {
		contract: CFrame,
		result: CFrame,
		crew: CFrame?,
		clock: CFrame?,
		daily: CFrame?,
	},
	bounds: Bounds,
}

local HUB = DepotLayoutConstants.HUB
-- A board marker faces its readers; the graybox's boards face +z (toward the spawns), so their marker is turned round.
local FLIP = CFrame.Angles(0, math.pi, 0)

local function whole(value: number, low: number, high: number): boolean
	return value == math.floor(value) and value >= low and value <= high
end

local DepotHubRules = {}

function DepotHubRules.plan(markers: { Marker }, bounds: Bounds): (Plan?, { string })
	local errors: { string } = {}
	local byNumber: { [number]: Marker } = {}
	local truckCount = 0
	local spawns: { CFrame } = {}
	local boards: { [string]: CFrame? } = {}
	for _, marker in markers do
		if marker.kind == "truck" then
			truckCount += 1
			local number = marker.truck
			if number == nil or byNumber[number] ~= nil then
				byNumber[-truckCount] = marker
			else
				byNumber[number] = marker
			end
		elseif marker.kind == "spawn" then
			table.insert(spawns, marker.cframe)
		else
			local kind = marker.board or "?"
			if HUB.BOARD_KINDS[kind] == nil then
				table.insert(errors, `a board spot says "{kind}": use one of contract, result, crew, clock, daily`)
			elseif boards[kind] ~= nil then
				table.insert(errors, `more than one {kind} board spot`)
			else
				boards[kind] = marker.cframe
			end
		end
	end

	if truckCount < DepotLayoutConstants.MIN_TRUCKS or truckCount > DepotLayoutConstants.MAX_TRUCKS then
		table.insert(
			errors,
			`{truckCount} trucks: a hub needs {DepotLayoutConstants.MIN_TRUCKS} to {DepotLayoutConstants.MAX_TRUCKS} truck bays`
		)
	end
	local trucks: { PlanTruck } = {}
	for index = 1, truckCount do
		local marker = byNumber[index]
		if marker == nil then
			table.insert(errors, `the truck bays must be numbered 1 to {truckCount}, each once`)
			break
		end
		local capacity = marker.capacity or DepotLayoutConstants.MAX_CAPACITY
		local countdown = marker.countdown or HUB.DEFAULT_COUNTDOWN
		if not whole(capacity, 1, DepotLayoutConstants.MAX_CAPACITY) then
			table.insert(
				errors,
				`truck {index}: seats must be a whole number from 1 to {DepotLayoutConstants.MAX_CAPACITY}`
			)
		end
		if countdown < DepotLayoutConstants.MIN_COUNTDOWN or countdown > DepotLayoutConstants.MAX_COUNTDOWN then
			table.insert(
				errors,
				`truck {index}: countdown must be {DepotLayoutConstants.MIN_COUNTDOWN} to {DepotLayoutConstants.MAX_COUNTDOWN} s`
			)
		end
		table.insert(trucks, {
			id = `truck{index}`,
			index = index,
			capacity = capacity,
			countdown = countdown,
			cframe = marker.cframe,
		})
	end
	if #spawns == 0 then
		table.insert(errors, "no spawn spot: a hub needs at least one")
	end
	local contract = boards.contract
	local result = boards.result
	if contract == nil then
		table.insert(errors, "no contract board spot")
	end
	if result == nil then
		table.insert(errors, "no result board spot")
	end
	if #errors > 0 or contract == nil or result == nil then
		return nil, errors
	end
	return {
		trucks = trucks,
		spawns = spawns,
		boards = {
			contract = contract,
			result = result,
			crew = boards.crew,
			clock = boards.clock,
			daily = boards.daily,
		},
		bounds = bounds,
	},
		errors
end

function DepotHubRules.fromLayout(layout: DepotTypes.Layout, origin: CFrame): Plan
	local trucks: { PlanTruck } = {}
	for index, truck in layout.trucks do
		table.insert(trucks, {
			id = truck.id,
			index = index,
			capacity = truck.capacity,
			countdown = truck.countdown,
			cframe = origin * CFrame.new(truck.x, 0, truck.z),
		})
	end
	local spawns: { CFrame } = {}
	for _, point in layout.spawns do
		table.insert(spawns, origin * CFrame.new(point.x, 0, point.z))
	end
	local function board(x: number, z: number): CFrame
		return origin * CFrame.new(x, 0, z) * FLIP
	end
	local contract = layout.contractBoard
	local crew = layout.crewBoard
	local floor = layout.floor
	local width = floor.maxX - floor.minX
	local depth = floor.maxZ - floor.minZ
	local height = DepotLayoutConstants.WALL_HEIGHT
	return {
		trucks = trucks,
		spawns = spawns,
		boards = {
			contract = board(contract.x, contract.z),
			result = board(layout.resultBoard.x, layout.resultBoard.z),
			crew = if crew ~= nil then board(crew.x, crew.z) else nil,
			clock = board(contract.x + HUB.GRAYBOX_CLOCK.x, contract.z + HUB.GRAYBOX_CLOCK.z),
			daily = board(contract.x + HUB.GRAYBOX_DAILY.x, contract.z + HUB.GRAYBOX_DAILY.z),
		},
		bounds = {
			cframe = origin * CFrame.new(floor.minX + width / 2, height / 2, floor.minZ + depth / 2),
			size = Vector3.new(width, height, depth),
		},
	}
end

--[=[
	The plan of the hub at `hubPath`, or an error that stops the depot: no quiet fallback (owner, 2026-11-10), so a
	builder sees at once what is wrong, every problem in one message with how the markers work.
]=]
function DepotHubRules.check(markers: { Marker }, bounds: Bounds, hubPath: string): Plan
	local plan, errors = DepotHubRules.plan(markers, bounds)
	if plan == nil then
		error(
			`THE HUB IS NOT PLAYABLE: {hubPath} (tagged {HUB.MODEL_TAG})\n- {table.concat(errors, "\n- ")}\n`
				.. `Fix the marker parts inside it: {HUB.TRUCK_TAG} (attribute {HUB.TRUCK_ATTRIBUTE} = 1..N), `
				.. `{HUB.SPAWN_TAG}, {HUB.BOARD_TAG} (attribute {HUB.BOARD_ATTRIBUTE} = contract, result, crew, clock or daily).`,
			0
		)
	end
	return plan
end

function DepotHubRules.inside(bounds: Bounds, point: Vector3): boolean
	local localPoint = bounds.cframe:PointToObjectSpace(point)
	local half = bounds.size / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

return DepotHubRules
