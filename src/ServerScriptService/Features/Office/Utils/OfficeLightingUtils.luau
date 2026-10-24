--!strict
--[=[
	OfficeLightingUtils: where an office room's lights go, from the approved spike. Hallways get troffer panels on
	the centre line plus alternating wall fills (and the matching sconce spots); rooms get a centred panel grid, about
	two thirds lit by a fixed pattern, and a coarser fill grid. No light casts shadows (the fills stopped too: light trim). Layout space, Y 0 is the
	floor top. Pure and deterministic.

	@class OfficeLightingUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

type LightPanel = OfficeTypes.LightPanel
type FillLight = OfficeTypes.FillLight
type Side = "minX" | "maxX" | "minZ" | "maxZ"
type Spot = { x: number, z: number, side: Side }
type HallSpot = { spot: Spot, inset: Vector2 }
type Recipe = { fillBrightness: number, fillRange: number, panelBrightness: number, allLit: boolean }

local HALL_PANEL_STEP = 8
local HALL_PANEL_START = 4
local HALL_FILL_STEP = 16
local HALL_FILL_START = 8
local HALL_FILL_INSET = 3
local HALL_FILL_Y = 5
local ROOM_PANEL_STEP_X = 12
local ROOM_PANEL_STEP_Z = 10
local ROOM_FILL_STEP_X = 22
local ROOM_FILL_STEP_Z = 18
local ROOM_FILL_Y = 4

local OfficeLightingUtils = {}

local function round(v: number): number
	return math.floor(v + 0.5)
end

local function recipe(roomType: string?): Recipe
	local lighting = OfficeConstants.LIGHTING
	local found = if roomType ~= nil then lighting[roomType] else nil
	return found or lighting.pods
end

-- The hall's run axis: x when the room is at least as wide as it is deep.
local function runsAlongX(room: OfficeTypes.Room): boolean
	return room.maxX - room.minX >= room.maxZ - room.minZ
end

-- Fill spots along a hall run with the wall each hangs beside; alternates, starting on the min side.
local function hallSpots(room: OfficeTypes.Room): { HallSpot }
	local alongX = runsAlongX(room)
	local start = if alongX then room.minX else room.minZ
	local stop = if alongX then room.maxX else room.maxZ
	local spots: { HallSpot } = {}
	local k = 0
	local at = HALL_FILL_START
	while start + at < stop do
		local minSide = k % 2 == 0
		local along = start + at
		local inset = if minSide then HALL_FILL_INSET else -HALL_FILL_INSET
		if alongX then
			local wall = if minSide then room.minZ else room.maxZ
			table.insert(spots, {
				spot = { x = along, z = wall, side = if minSide then "minZ" else "maxZ" },
				inset = Vector2.new(0, inset),
			})
		else
			local wall = if minSide then room.minX else room.maxX
			table.insert(spots, {
				spot = { x = wall, z = along, side = if minSide then "minX" else "maxX" },
				inset = Vector2.new(inset, 0),
			})
		end
		k += 1
		at += HALL_FILL_STEP
	end
	return spots
end

-- Centred grid coordinate: cell `index` (1-based) of n cells of `step` studs around `centre`.
local function gridAt(centre: number, n: number, step: number, index: number): number
	return centre + (index - (n + 1) / 2) * step
end

local function makeFill(position: Vector3, light: Recipe): FillLight
	return {
		position = position,
		brightness = light.fillBrightness,
		range = light.fillRange,
		color = OfficeConstants.FILL_COLOR,
		shadows = false,
	}
end

function OfficeLightingUtils.sconceSpots(room: OfficeTypes.Room): { Spot }
	local out: { Spot } = {}
	for _, entry in hallSpots(room) do
		table.insert(out, entry.spot)
	end
	return out
end

function OfficeLightingUtils.roomLights(
	room: OfficeTypes.Room,
	roomType: string?
): { panels: { LightPanel }, fills: { FillLight } }
	local light = recipe(roomType)
	local panels: { LightPanel } = {}
	local fills: { FillLight } = {}
	local centreX = (room.minX + room.maxX) / 2
	local centreZ = (room.minZ + room.maxZ) / 2

	if roomType == "hallway" then
		local alongX = runsAlongX(room)
		local start = if alongX then room.minX else room.minZ
		local stop = if alongX then room.maxX else room.maxZ
		local at = HALL_PANEL_START
		while start + at < stop do
			table.insert(panels, {
				x = if alongX then start + at else centreX,
				z = if alongX then centreZ else start + at,
				lit = true,
				rotated = not alongX,
				brightness = light.panelBrightness,
			})
			at += HALL_PANEL_STEP
		end
		for _, entry in hallSpots(room) do
			local position = Vector3.new(entry.spot.x + entry.inset.X, HALL_FILL_Y, entry.spot.z + entry.inset.Y)
			table.insert(fills, makeFill(position, light))
		end
		return { panels = panels, fills = fills }
	end

	local width = room.maxX - room.minX
	local depth = room.maxZ - room.minZ

	local nx = math.max(1, round(width / ROOM_PANEL_STEP_X))
	local nz = math.max(1, round(depth / ROOM_PANEL_STEP_Z))
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			table.insert(panels, {
				x = gridAt(centreX, nx, ROOM_PANEL_STEP_X, i + 1),
				z = gridAt(centreZ, nz, ROOM_PANEL_STEP_Z, j + 1),
				lit = light.allLit or (i + 2 * j) % 3 ~= 1,
				rotated = false,
				brightness = light.panelBrightness,
			})
		end
	end

	local fx = math.max(1, round(width / ROOM_FILL_STEP_X))
	local fz = math.max(1, round(depth / ROOM_FILL_STEP_Z))
	for i = 1, fx do
		for j = 1, fz do
			local position = Vector3.new(
				gridAt(centreX, fx, ROOM_FILL_STEP_X, i),
				ROOM_FILL_Y,
				gridAt(centreZ, fz, ROOM_FILL_STEP_Z, j)
			)
			table.insert(fills, makeFill(position, light))
		end
	end
	return { panels = panels, fills = fills }
end

function OfficeLightingUtils.accentFor(attachmentName: string): { brightness: number, range: number, color: Color3 }?
	return OfficeConstants.ACCENT_LIGHTS[attachmentName]
end

return OfficeLightingUtils
