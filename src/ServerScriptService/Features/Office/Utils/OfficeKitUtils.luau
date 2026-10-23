--!strict
--[=[
	OfficeKitUtils: places a hand-authored kit room in the office: rotates it so its front wall lies on the
	requested edge, optionally mirrors it, and returns the room, its front door, its glass pane and its
	markers in office-local studs. Pure.

	@class OfficeKitUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)

type Kit = OfficeTypes.Kit
type Edge = OfficeTypes.Edge
type Placement = OfficeTypes.Placement

-- Yaw of the kit's local frame for each front edge.
local FACING_YAW: { [Edge]: number } = {
	minZ = 0,
	minX = math.pi / 2,
	maxZ = math.pi,
	maxX = -math.pi / 2,
}

local OfficeKitUtils = {}

-- Studs snap to 1e-6 so quarter turns land on exact values (doorEdge compares with ==).
local function snap(value: number): number
	return math.round(value * 1e6) / 1e6
end

function OfficeKitUtils.place(
	kit: Kit,
	roomId: string,
	frontX: number,
	frontZ: number,
	facing: Edge,
	mirrored: boolean
): Placement
	local theta = FACING_YAW[facing]
	local cos, sin = math.cos(theta), math.sin(theta)

	-- CFrame.Angles(0, theta, 0) applied to (x, 0, z), then offset by the front-left corner.
	local function toWorld(x: number, z: number): (number, number)
		local localX = if mirrored then kit.width - x else x
		return snap(frontX + localX * cos + z * sin), snap(frontZ - localX * sin + z * cos)
	end

	local ax, az = toWorld(0, 0)
	local bx, bz = toWorld(kit.width, kit.depth)
	local doorX, doorZ = toWorld(kit.door.offset, 0)

	local pane: OfficeTypes.Segment? = nil
	if kit.glass then
		local x1, z1 = toWorld(kit.glass.from, 0)
		local x2, z2 = toWorld(kit.glass.to, 0)
		pane = { x1 = math.min(x1, x2), z1 = math.min(z1, z2), x2 = math.max(x1, x2), z2 = math.max(z1, z2) }
	end

	local counts: { [string]: number } = {}
	local markers: { OfficeTypes.Marker } = {}
	for _, source in kit.markers do
		local n = (counts[source.kind] or 0) + 1
		counts[source.kind] = n
		local x, z = toWorld(source.x, source.z)
		local yaw = source.rotation or 0
		table.insert(markers, {
			id = `{roomId}.{source.kind}.{n}`,
			room = roomId,
			kind = source.kind,
			x = x,
			z = z,
			rotation = theta + (if mirrored then -yaw else yaw),
			art = source.art,
		})
	end

	return {
		room = {
			id = roomId,
			name = kit.name,
			minX = math.min(ax, bx),
			minZ = math.min(az, bz),
			maxX = math.max(ax, bx),
			maxZ = math.max(az, bz),
			zone = kit.roomType,
			floor = OfficeConstants.FLOOR_NUMBER,
			kit = kit.id,
			roomType = kit.roomType,
		},
		doorX = doorX,
		doorZ = doorZ,
		doorWidth = kit.door.width,
		doorKind = kit.door.kind,
		pane = pane,
		markers = markers,
	}
end

return OfficeKitUtils
