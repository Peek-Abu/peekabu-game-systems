--!strict
--[=[
	OfficeDoorUtils: the maths of the office's real doors. Where a door leaf stands at a fraction of its swing, which
	way it swings, which closed doors a walker is walking through (in reach, ahead and on his line of travel), where the
	elevator front stands, the rattle of a locked door, whether an NPC is near a door, and whether a doorway is clear enough to close. Pure.

	Frames are in layout space: pass the office origin to get world space. A leaf is the clear opening inside the oak
	casing, a box (`leafSize`: door.width - 2 x casing by DOOR_HEIGHT - casing, DOOR_LEAF_THICKNESS thick) centred in
	the wall line at half its height, turned a quarter turn for a door on an X edge (minX / maxX) so its width runs
	along Z. It hinges at the door's "-side" edge of the leaf: x - leafWidth/2 for a door on a Z edge (minZ / maxZ,
	"horizontal"), z - leafWidth/2 for a door on an X edge ("vertical").

	Hinge side: the hinge always sits at the leaf's local +X (door art authors its hinge there), so a Z-edge door's
	closed leaf is turned half a turn and an X-edge door's a quarter turn; facades use the same orientations. The leaf
	is a symmetric box, so collision and the swing arc do not depend on it.

	Swing sign: positive swings the free end toward +Z for a horizontal door and toward +X for a vertical one;
	negative the other way. `swingSign` picks the sign that swings INTO the non-hallway room.

	@class OfficeDoorUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeDecorConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeLayoutUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutUtils)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

type Door = OfficeTypes.Door
type Edge = OfficeTypes.Edge
type Room = OfficeTypes.Room
type Facade = OfficeTypes.Facade

-- A real door's id, world centre, width (along its wall) and whether it stands open.
export type DoorState = { id: string, position: Vector3, width: number, open: boolean }

-- Bodies this close (studs, each axis) to the doorway keep it from closing.
local BODY_MARGIN = 1
-- Back-and-forth jiggles in one rattle.
local RATTLE_JIGGLES = 3
-- Mr. Harlow's agent radius (studs): a door is on his line when its centre is within its half-width plus this of it.
local AGENT_RADIUS = 1

local OfficeDoorUtils = {}

--[=[
	A solid or glass door's leaf: the clear opening inside the casing. X is the width along the wall, Y the height
	from the floor, Z the leaf's thickness.
]=]
function OfficeDoorUtils.leafSize(door: Door): Vector3
	local casing = OfficeConstants.SHELL.casing
	return Vector3.new(
		door.width - 2 * casing,
		OfficeConstants.DOOR_HEIGHT - casing,
		OfficeConstants.DOOR_LEAF_THICKNESS
	)
end

local function isHorizontal(edge: Edge): boolean
	return edge == "minZ" or edge == "maxZ"
end

--[=[
	The leaf's CFrame (relative to `origin`) at `fraction` (0 closed .. 1 fully open) of its swing: the closed frame
	turned about the vertical axis through the hinge by `fraction * DOOR_OPEN_ANGLE`, toward `swingSign`'s side.
]=]
function OfficeDoorUtils.leafFrame(door: Door, edge: Edge, swingSign: number, fraction: number, origin: CFrame): CFrame
	local horizontal = isHorizontal(edge)
	local size = OfficeDoorUtils.leafSize(door)
	local closed = CFrame.new(door.x, size.Y / 2, door.z)
		* CFrame.Angles(0, if horizontal then math.pi else math.pi / 2, 0)
	local hinge = CFrame.new(
		if horizontal then door.x - size.X / 2 else door.x,
		0,
		if horizontal then door.z else door.z - size.X / 2
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
	local half = CFrame.Angles(0, math.pi, 0)
	if math.abs(facade.z - room.minZ) < 1e-4 then
		return origin * CFrame.new(facade.x, y, facade.z + inset) * half
	elseif math.abs(facade.z - room.maxZ) < 1e-4 then
		return origin * CFrame.new(facade.x, y, facade.z - inset) * half
	elseif math.abs(facade.x - room.minX) < 1e-4 then
		return origin * CFrame.new(facade.x + inset, y, facade.z) * quarter
	elseif math.abs(facade.x - room.maxX) < 1e-4 then
		return origin * CFrame.new(facade.x - inset, y, facade.z) * quarter
	end
	return nil
end

--[=[
	Where an elevator facade's front stands (layout space, relative to `origin`): flush on the room side of the wall it
	fronts, at the elevator's height (ELEVATOR_POINT.Y), local +Z pointing into the room. Nil when (x, z) is on none
	of the room's walls.
]=]
function OfficeDoorUtils.elevatorFrame(facade: Facade, room: Room, origin: CFrame): CFrame?
	local edge = OfficeLayoutUtils.facadeEdge(room, facade)
	if edge == nil then
		return nil
	end
	local inset = OfficeConstants.WALL_THICKNESS / 2 + OfficeConstants.ELEVATOR_FRONT_SIZE.Z / 2
	local into = if edge == "minZ"
		then Vector3.new(0, 0, 1)
		elseif edge == "maxZ" then Vector3.new(0, 0, -1)
		elseif edge == "minX" then Vector3.new(1, 0, 0)
		else Vector3.new(-1, 0, 0)
	local position = Vector3.new(facade.x, OfficeDecorConstants.ELEVATOR_POINT.Y, facade.z) + into * inset
	-- lookAt points local -Z at its target, so aim away from the room to point +Z into it.
	return origin * CFrame.lookAt(position, position - into)
end

--[=[
	Where the elevator front stands in `layout` (relative to `origin`): on its first elevator facade (`elevatorFrame`),
	else, in a layout with none (the authored boot layout), at OfficeDecorConstants.ELEVATOR_POINT with local +Z
	facing world +X, its fixed pose before elevators stood on facades.
]=]
function OfficeDoorUtils.elevatorFrameFor(layout: OfficeTypes.Layout, origin: CFrame): CFrame
	local facades: { Facade } = layout.facades or {}
	for _, facade in facades do
		if facade.kind == "elevator" then
			local room = OfficeLayoutUtils.room(layout, facade.room)
			local frame = if room ~= nil then OfficeDoorUtils.elevatorFrame(facade, room, origin) else nil
			if frame ~= nil then
				return frame
			end
			break
		end
	end
	return origin * CFrame.new(OfficeDecorConstants.ELEVATOR_POINT) * CFrame.Angles(0, math.pi / 2, 0)
end

--[=[
	The leaves of a facade, each as `size` (X along the wall, Y height, Z thickness), `offset` from the facade frame
	(`facadeFrame`: X along the wall, Y down from the frame's half-height) and `side` (-1 / 0 / +1: which half of the
	facade it hangs on, 0 for a single leaf). They fill the clear opening inside the facade's oak casing, as a real
	door's does: width - 2 x casing by DOOR_HEIGHT - casing. An entrance is two glass leaves side by side, a stairwell
	one solid leaf.
]=]
function OfficeDoorUtils.facadeLeaves(facade: Facade): { { size: Vector3, offset: Vector3, side: number } }
	local casing = OfficeConstants.SHELL.casing
	local count = if facade.kind == "entrance" then 2 else 1
	local width = (facade.width - 2 * casing) / count
	local leaves: { { size: Vector3, offset: Vector3, side: number } } = {}
	for index = 1, count do
		local side = if count == 1 then 0 elseif index == 1 then -1 else 1
		table.insert(leaves, {
			size = Vector3.new(width, OfficeConstants.DOOR_HEIGHT - casing, OfficeConstants.DOOR_LEAF_THICKNESS),
			offset = Vector3.new(side * width / 2, -casing / 2, 0),
			side = side,
		})
	end
	return leaves
end

--[=[
	The ids of the closed doors a walker at `point` heading `heading` is walking through: the door lies on his line of
	travel. Its centre is within `radius` studs on the ground plane (XZ), ahead of him (a positive distance along the
	heading) and within door.width / 2 + AGENT_RADIUS of his heading line (the perpendicular distance), so a side door
	he walks past along a corridor is not one. With no heading, or one with no ground-plane part, nothing lies ahead of
	him and no door is returned.
]=]
function OfficeDoorUtils.reach(doors: { DoorState }, point: Vector3, heading: Vector3?, radius: number): { string }
	local ids: { string } = {}
	local flat = if heading ~= nil then Vector3.new(heading.X, 0, heading.Z) else Vector3.zero
	if flat.Magnitude < 1e-4 then
		return ids
	end
	local ux, uz = flat.Unit.X, flat.Unit.Z
	for _, state in doors do
		local dx = state.position.X - point.X
		local dz = state.position.Z - point.Z
		local forward = dx * ux + dz * uz
		local lateral = math.abs(dx * uz - dz * ux)
		local onLine = lateral <= state.width / 2 + AGENT_RADIUS
		if not state.open and forward > 0 and dx * dx + dz * dz <= radius * radius and onLine then
			table.insert(ids, state.id)
		end
	end
	return ids
end

--[=[
	The turn of a locked door's rattle at fraction `t` (0 .. 1) of DOOR_RATTLE_SECONDS: a few small yaw jiggles of up
	to DOOR_RATTLE_ANGLE that die away, applied on the right of the leaf's own frame (so about its centre). Exactly the
	identity at t <= 0 and t >= 1.
]=]
function OfficeDoorUtils.rattle(t: number): CFrame
	if t <= 0 or t >= 1 then
		return CFrame.identity
	end
	local swing = math.sin(t * 2 * math.pi * RATTLE_JIGGLES) * (1 - t)
	return CFrame.Angles(0, OfficeConstants.DOOR_RATTLE_ANGLE * swing, 0)
end

--[=[
	Whether any of `points` (NPC roots) is within `radius` studs of `centre` on the ground plane (XZ).
]=]
function OfficeDoorUtils.npcNear(points: { Vector3 }, centre: Vector3, radius: number): boolean
	local limit = radius * radius
	for _, point in points do
		local dx, dz = point.X - centre.X, point.Z - centre.Z
		if dx * dx + dz * dz <= limit then
			return true
		end
	end
	return false
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
