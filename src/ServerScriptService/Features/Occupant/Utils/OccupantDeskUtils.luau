--!strict
--[=[
	OccupantDeskUtils: the Manager at the office's desks (docs/superpowers/specs/2026-10-15-cleanup-crew-manager-behaviours-
	design.md §1–§3).

	- `pick`: the desk for a work break. "Near the crew" takes the desk whose seat is PICK_NEAR studs from the nearest
	  crew member, closest to PICK_IDEAL; "elsewhere" a desk at least PICK_FAR from everyone, by roll; failing both, any
	  free desk. Never a desk someone hides under, the last desk he used, a desk a player stands within PICK_CLEAR of,
	  or one in the loading bay.
	- `seatFrame`: where his root goes on a chair (OccupantAssets.SEAT: over the chair's centre at standing height,
	  facing the desk) and whether the chair is on the desk's knee-hole side (the desk's -Z, its front); `fallbackChair`
	  is where the chair stands without its art (3.05 studs in front, Office's chair rule).
	- `standPoint`: where he stands to stare at a hiding spot (STARE_GAP off its front edge, STARE_SIDE beside the chair,
	  on the floor); `standPoints` the candidates in order (that side, the other side, straight out further).
	- `sitBack`: a seat moved back, away from the desk (a sit-in clears the hider's huddle).
	- `standUp`: where his root ends when he stands up from a seat: the stand-up clip's offset, pulled straight back
	  from the desk until his body clears its footprint. (2026-10-16, the play-again freeze: the clip's 1.1-stud step
	  forward put his root inside the desk; physics shoved him out behind it, wedged against the wall where no path
	  exists, and the costed NPC mover never steers without a path, so he stood still and never turned, even in a
	  chase.)
	- `nearestFrom`: the free desk nearest a point but at least some distance off (the developer's ambush summon).
	- `facing`: a frame at a point looking at a target at the same height.

	Distances are flat (X/Z). Pure.

	@class OccupantDeskUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)

type Desk = OccupantTypes.Desk

export type PickInput = {
	crew: { Vector3 },
	-- Spot ids someone hides in.
	occupied: { [string]: boolean },
	last: string?,
	near: boolean,
	roll: number,
	bay: OccupantTypes.Zone?,
}

-- Office's chair rule: a desk's chair stands this far in front of its centre (OfficeLayoutRoomUtils).
local CHAIR_DISTANCE = 3.05

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function inBox(point: Vector3, zone: OccupantTypes.Zone?): boolean
	return zone ~= nil
		and point.X >= zone.min.X
		and point.X <= zone.max.X
		and point.Z >= zone.min.Z
		and point.Z <= zone.max.Z
end

local function nearestCrew(point: Vector3, crew: { Vector3 }): number
	local nearest = math.huge
	for _, member in crew do
		nearest = math.min(nearest, flat(point, member))
	end
	return nearest
end

local OccupantDeskUtils = {}

function OccupantDeskUtils.pick(desks: { Desk }, input: PickInput): Desk?
	local free: { Desk } = {}
	for _, desk in desks do
		local position = desk.seat.Position
		local spot = desk.spotId
		if
			not (spot ~= nil and input.occupied[spot] == true)
			and desk.id ~= input.last
			and nearestCrew(position, input.crew) > OccupantConstants.PICK_CLEAR
			and not inBox(position, input.bay)
		then
			table.insert(free, desk)
		end
	end
	if #free == 0 then
		return nil
	end
	if input.near then
		local best: Desk? = nil
		local bestError = math.huge
		for _, desk in free do
			local distance = nearestCrew(desk.seat.Position, input.crew)
			local band = OccupantConstants.PICK_NEAR
			if distance >= band.min and distance <= band.max then
				local miss = math.abs(distance - OccupantConstants.PICK_IDEAL)
				if miss < bestError then
					best = desk
					bestError = miss
				end
			end
		end
		if best ~= nil then
			return best
		end
	else
		local far: { Desk } = {}
		for _, desk in free do
			if nearestCrew(desk.seat.Position, input.crew) >= OccupantConstants.PICK_FAR then
				table.insert(far, desk)
			end
		end
		if #far > 0 then
			return far[math.clamp(math.floor(math.clamp(input.roll, 0, 1) * #far) + 1, 1, #far)]
		end
	end
	return free[math.clamp(math.floor(math.clamp(input.roll, 0, 1) * #free) + 1, 1, #free)]
end

--[=[
	The desk whose seat is nearest `point` and at least `minDistance` flat studs from it, never one someone hides under
	(`occupied` spot ids); nil when none. A developer's summon (the ambush repro command).
]=]
function OccupantDeskUtils.nearestFrom(
	desks: { Desk },
	point: Vector3,
	minDistance: number,
	occupied: { [string]: boolean }
): Desk?
	local best: Desk? = nil
	local bestDistance = math.huge
	for _, desk in desks do
		local spot = desk.spotId
		local distance = flat(desk.seat.Position, point)
		if not (spot ~= nil and occupied[spot] == true) and distance >= minDistance and distance < bestDistance then
			best = desk
			bestDistance = distance
		end
	end
	return best
end

function OccupantDeskUtils.facing(at: Vector3, target: Vector3): CFrame
	local toward = Vector3.new(target.X, at.Y, target.Z)
	if flat(at, toward) < 1e-3 then
		return CFrame.new(at)
	end
	return CFrame.lookAt(at, toward)
end

--[=[
	His root's frame on the chair at `chairPosition` (any height) for the desk at `desk`, on a floor at `floorY`, and
	whether the chair is on the desk's front (knee-hole) side.
]=]
function OccupantDeskUtils.seatFrame(
	chairPosition: Vector3,
	desk: CFrame,
	floorY: number,
	standHeight: number
): (CFrame, boolean)
	local at = Vector3.new(chairPosition.X, floorY + standHeight, chairPosition.Z)
	local offset = chairPosition - desk.Position
	local front = Vector3.new(offset.X, 0, offset.Z):Dot(desk.LookVector) > 0
	return OccupantDeskUtils.facing(at, desk.Position), front
end

function OccupantDeskUtils.fallbackChair(desk: CFrame): Vector3
	return (desk * CFrame.new(0, 0, -CHAIR_DISTANCE)).Position
end

--[=[
	Where he stands to stare at the spot whose frame is `spotFrame` (front = its -Z) on furniture of `size`: `gap` off
	the front edge and `side` to its right (beside a desk's chair, which stands on the centre line).
]=]
function OccupantDeskUtils.standPoint(spotFrame: CFrame, size: Vector3, gap: number, side: number): Vector3
	return (spotFrame * CFrame.new(side, -size.Y / 2, -(size.Z / 2 + gap))).Position
end

--[=[
	Where he may stand to stare at the spot, best first: `standPoint` beside it, then the other side, then straight out
	from its front, STAND_OUT further. The caller takes the first one clear of furniture.
]=]
function OccupantDeskUtils.standPoints(spotFrame: CFrame, size: Vector3, gap: number, side: number): { Vector3 }
	return {
		OccupantDeskUtils.standPoint(spotFrame, size, gap, side),
		OccupantDeskUtils.standPoint(spotFrame, size, gap, -side),
		OccupantDeskUtils.standPoint(spotFrame, size, gap + OccupantConstants.STAND_OUT, 0),
	}
end

function OccupantDeskUtils.sitBack(seat: CFrame, back: number): CFrame
	return seat * CFrame.new(0, 0, back)
end

-- Flat studs from `point` to the footprint of the desk at `desk` of `size` (0 inside it).
local function clearanceOf(point: Vector3, desk: CFrame, size: Vector3): number
	local inDesk = desk:PointToObjectSpace(point)
	local dx = math.max(math.abs(inDesk.X) - size.X / 2, 0)
	local dz = math.max(math.abs(inDesk.Z) - size.Z / 2, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- How far (studs) he may be pulled back, and the step.
local STAND_PULL_MAX = 4
local STAND_PULL_STEP = 0.05

--[=[
	Where his root ends standing up from `seat` (facing the desk): `seat` moved by the stand-up clip's `offset`, pulled
	straight back (away from the desk, along the seat's back) until it is `radius` flat studs clear of the footprint of
	the desk at `desk` of `size`, at most STAND_PULL_MAX. Unchanged when it is already clear.
]=]
function OccupantDeskUtils.standUp(seat: CFrame, offset: Vector3, desk: CFrame, size: Vector3, radius: number): CFrame
	local stood = seat * CFrame.new(offset)
	local pulled = 0
	while clearanceOf(stood.Position, desk, size) < radius and pulled < STAND_PULL_MAX do
		pulled += STAND_PULL_STEP
		stood = seat * CFrame.new(offset) * CFrame.new(0, 0, pulled)
	end
	return stood
end

return OccupantDeskUtils
