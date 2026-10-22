--!strict
--[=[
	OfficeDoorUtils: the maths of the office's real doors. Where a door leaf stands at a fraction of its swing, which
	way it swings, which closed doors are near a point, and whether a doorway is clear enough to close. Pure.

	Frames are in layout space: pass the office origin to get world space. A leaf is a box (door.width x
	DOOR_HEIGHT x DOOR_LEAF_THICKNESS) centred in the wall line at height DOOR_HEIGHT / 2, turned a quarter turn
	for a door on an X edge (minX / maxX) so its width runs along Z. It hinges at the door's "-side" jamb: x - width/2
	for a door on a Z edge (minZ / maxZ, "horizontal"), z - width/2 for a door on an X edge ("vertical").

	Swing sign: positive swings the free end toward +Z for a horizontal door and toward +X for a vertical one;
	negative the other way. `swingSign` picks the sign that swings INTO the non-hallway room.

	@class OfficeDoorUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

type Door = OfficeTypes.Door
type Edge = OfficeTypes.Edge
type Room = OfficeTypes.Room
type Facade = OfficeTypes.Facade

export type DoorState = { id: string, position: Vector3, open: boolean }

-- Bodies this close (studs, each axis) to the doorway keep it from closing.
local BODY_MARGIN = 1

local OfficeDoorUtils = {}

local function isHorizontal(edge: Edge): boolean
	return edge == "minZ" or edge == "maxZ"
end

--[=[
	The leaf's CFrame (relative to `origin`) at `fraction` (0 closed .. 1 fully open) of its swing: the closed frame
	turned about the vertical axis through the hinge by `fraction * DOOR_OPEN_ANGLE`, toward `swingSign`'s side.
]=]
function OfficeDoorUtils.leafFrame(door: Door, edge: Edge, swingSign: number, fraction: number, origin: CFrame): CFrame
	local horizontal = isHorizontal(edge)
	local closed = CFrame.new(door.x, OfficeConstants.DOOR_HEIGHT / 2, door.z)
		* (if horizontal then CFrame.identity else CFrame.Angles(0, math.pi / 2, 0))
	local hinge = CFrame.new(
		if horizontal then door.x - door.width / 2 else door.x,
		0,
		if horizontal then door.z else door.z - door.width / 2
	)
	-- Turning about +Y by a positive angle takes +X toward -Z and +Z toward +X.
	local angle = swingSign * fraction * OfficeConstants.DOOR_OPEN_ANGLE
	if horizontal then
		angle = -angle
	end
	return origin * hinge * CFrame.Angles(0, angle, 0) * hinge:Inverse() * closed
end

--[=[
	The sign (+1 / -1) that swings the leaf into the room that is not a hallway. `roomA` is the room the door's
	`edge` belongs to (door.a); the other side is the opposite room. Into `a` when `a` is not a hallway (also when
	neither or both are, where the door has no leaf anyway), into the other room when `a` is the hallway.
]=]
function OfficeDoorUtils.swingSign(_door: Door, edge: Edge, roomA: Room): number
	-- Into room A is toward +Z / +X from a min edge, away from it from a max edge.
	local intoA = if edge == "minZ" or edge == "minX" then 1 else -1
	return if roomA.zone == "hallway" then -intoA else intoA
end

--[=[
	Where a facade's closed leaf stands (layout space, relative to `origin`): flush on the room side of the wall it
	fronts, centred at DOOR_HEIGHT / 2. Nil when (x, z) is on none of the room's walls.
]=]
function OfficeDoorUtils.facadeFrame(facade: Facade, room: Room, origin: CFrame): CFrame?
	local inset = OfficeConstants.WALL_THICKNESS / 2 + OfficeConstants.DOOR_LEAF_THICKNESS / 2
	local y = OfficeConstants.DOOR_HEIGHT / 2
	local quarter = CFrame.Angles(0, math.pi / 2, 0)
	if math.abs(facade.z - room.minZ) < 1e-4 then
		return origin * CFrame.new(facade.x, y, facade.z + inset)
	elseif math.abs(facade.z - room.maxZ) < 1e-4 then
		return origin * CFrame.new(facade.x, y, facade.z - inset)
	elseif math.abs(facade.x - room.minX) < 1e-4 then
		return origin * CFrame.new(facade.x + inset, y, facade.z) * quarter
	elseif math.abs(facade.x - room.maxX) < 1e-4 then
		return origin * CFrame.new(facade.x - inset, y, facade.z) * quarter
	end
	return nil
end

--[=[
	The ids of the closed doors whose centre is within `radius` studs of `point` on the ground plane (XZ).
]=]
function OfficeDoorUtils.near(doors: { DoorState }, point: Vector3, radius: number): { string }
	local ids: { string } = {}
	local limit = radius * radius
	for _, state in doors do
		if not state.open then
			local dx = state.position.X - point.X
			local dz = state.position.Z - point.Z
			if dx * dx + dz * dz <= limit then
				table.insert(ids, state.id)
			end
		end
	end
	return ids
end

--[=[
	Whether the doorway box (min and max corners, world) is clear to close: false when any body is inside the box
	grown by one stud on every side.
]=]
function OfficeDoorUtils.canClose(doorwayMin: Vector3, doorwayMax: Vector3, bodies: { Vector3 }): boolean
	local margin = Vector3.one * BODY_MARGIN
	local low = doorwayMin - margin
	local high = doorwayMax + margin
	for _, body in bodies do
		if
			body.X >= low.X
			and body.X <= high.X
			and body.Y >= low.Y
			and body.Y <= high.Y
			and body.Z >= low.Z
			and body.Z <= high.Z
		then
			return false
		end
	end
	return true
end

return OfficeDoorUtils
