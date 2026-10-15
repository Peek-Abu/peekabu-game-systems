--!strict
--[=[
	DepotMarkingUtils: plans the depot's garage floor from its layout (hub v1: "kids find their truck without reading
	the floating tag"; "a proper garage floor"). `plan`: per truck, in layout order, a "BAY n" stencil in front of
	the ramp, a yellow-and-black hazard band across the ramp's foot, two yellow side lines framing the bay clear of
	the truck, a dashed yellow lane from behind the spawn strip to the bay's front, and a few faint oil stains. Every
	piece is a thin slab in the depot's local space (y up from the floor's top) and no two overlap, so nothing
	z-fights. `slabs`: the concrete slabs the paint lies on, with real expansion-joint gaps between them.
	DepotBuildSystem lays both. Pure.

	@class DepotMarkingUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)
local DepotTruckVisualConstants = require(ServerScriptService.Features.Depot.Data.DepotTruckVisualConstants)

-- A flat painted slab (`round`: a disc `size.X` across).
export type Paint = {
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	round: boolean,
	transparency: number,
}

-- One concrete slab.
export type Slab = {
	size: Vector3,
	position: Vector3,
	color: Color3,
}

-- A stencil: an invisible slab whose top face carries `text`.
export type Label = {
	name: string,
	size: Vector3,
	position: Vector3,
	text: string,
}

export type Plan = {
	paints: { Paint },
	labels: { Label },
}

local MARKING = DepotLayoutConstants.MARKING

local function slab(sizeX: number, sizeZ: number, x: number, z: number): (Vector3, Vector3)
	local thickness = MARKING.THICKNESS
	return Vector3.new(sizeX, thickness, sizeZ), Vector3.new(x, MARKING.LIFT + thickness / 2, z)
end

local function paint(paints: { Paint }, name: string, sizeX: number, sizeZ: number, x: number, z: number, color: Color3)
	local size, position = slab(sizeX, sizeZ, x, z)
	table.insert(
		paints,
		{ name = name, size = size, position = position, color = color, round = false, transparency = 0 }
	)
end

local DepotMarkingUtils = {}

function DepotMarkingUtils.plan(layout: DepotTypes.Layout): Plan
	local paints: { Paint } = {}
	local labels: { Label } = {}
	local line = MARKING.LINE_WIDTH
	for index, truck in layout.trucks do
		-- The ramp's foot: the front of the truck's whole footprint.
		local foot = truck.z - DepotTruckVisualConstants.BACK
		local bayFront = foot - MARKING.BAY_FRONT
		local bayBack = layout.floor.maxZ - MARKING.BAY_BACK_GAP

		-- The hazard band, yellow at both ends.
		local count = math.floor(MARKING.HAZARD_WIDTH / MARKING.STRIPE)
		if count % 2 == 0 then
			count -= 1
		end
		local left = truck.x - count * MARKING.STRIPE / 2
		local bandZ = foot - MARKING.HAZARD_DEPTH / 2
		for stripe = 1, count do
			local color = if stripe % 2 == 1 then MARKING.YELLOW else MARKING.BLACK
			local x = left + (stripe - 0.5) * MARKING.STRIPE
			paint(paints, `Hazard{index}_{stripe}`, MARKING.STRIPE, MARKING.HAZARD_DEPTH, x, bandZ, color)
		end

		-- The stencil, centred between the bay's front and the hazard band.
		local labelSize = MARKING.LABEL_SIZE
		local labelZ = (bayFront + foot - MARKING.HAZARD_DEPTH) / 2
		local size, position = slab(labelSize.X, labelSize.Y, truck.x, labelZ)
		table.insert(labels, { name = `BayLabel{index}`, size = size, position = position, text = `BAY {index}` })

		-- The side lines.
		local sideLength = bayBack - bayFront
		local sideZ = (bayFront + bayBack) / 2
		for side, sign in { -1, 1 } do
			local x = truck.x + sign * (MARKING.BAY_HALF_WIDTH + line / 2)
			paint(paints, `BayLine{index}_{side}`, line, sideLength, x, sideZ, MARKING.YELLOW)
		end

		-- The lane: whole dashes from LANE_START_Z, the last one ending at or before the bay's front.
		local dash = 1
		local z = MARKING.LANE_START_Z
		while z + MARKING.DASH <= bayFront do
			paint(paints, `Lane{index}_{dash}`, line, MARKING.DASH, truck.x, z + MARKING.DASH / 2, MARKING.YELLOW)
			dash += 1
			z += MARKING.DASH + MARKING.GAP
		end
	end
	for index, stain in MARKING.STAINS do
		local truck = layout.trucks[stain.truck]
		if truck ~= nil then
			local bayFront = truck.z - DepotTruckVisualConstants.BACK - MARKING.BAY_FRONT
			local size, position = slab(stain.diameter, stain.diameter, truck.x + stain.dx, bayFront + stain.dz)
			table.insert(paints, {
				name = `Stain{index}`,
				size = size,
				position = position,
				color = MARKING.STAIN_COLOR,
				round = true,
				transparency = MARKING.STAIN_TRANSPARENCY,
			})
		end
	end
	return { paints = paints, labels = labels }
end

-- The edges of grid cell `index` (1-based) of `size` studs from `min` to `max`: an inner edge gives up half a joint.
local function span(min: number, max: number, index: number, size: number): (number, number)
	local low = min + (index - 1) * size
	local high = math.min(low + size, max)
	local half = MARKING.JOINT / 2
	return if index > 1 then low + half else low, if high < max then high - half else high
end

--[=[
	The concrete slabs over `floor`, across x first then down z: SLAB studs a side (the last row and column take what
	is left), JOINT apart, JOINT_DEPTH thick, topped at the floor plane, each one of SLAB_COLORS in a fixed pattern.
]=]
function DepotMarkingUtils.slabs(floor: DepotTypes.Rect): { Slab }
	local slabs: { Slab } = {}
	local size = MARKING.SLAB
	local columns = math.ceil((floor.maxX - floor.minX) / size)
	local rows = math.ceil((floor.maxZ - floor.minZ) / size)
	local colors = MARKING.SLAB_COLORS
	for row = 1, rows do
		local minZ, maxZ = span(floor.minZ, floor.maxZ, row, size)
		for column = 1, columns do
			local minX, maxX = span(floor.minX, floor.maxX, column, size)
			table.insert(slabs, {
				size = Vector3.new(maxX - minX, MARKING.JOINT_DEPTH, maxZ - minZ),
				position = Vector3.new((minX + maxX) / 2, -MARKING.JOINT_DEPTH / 2, (minZ + maxZ) / 2),
				color = colors[(column * 2 + row * 3) % #colors + 1],
			})
		end
	end
	return slabs
end

return DepotMarkingUtils
