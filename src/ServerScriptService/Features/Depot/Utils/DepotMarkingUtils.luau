--!strict
--[=[
	DepotMarkingUtils: plans the depot's floor paint from its layout (hub v1: "kids find their truck without reading
	the floating tag"). Per truck, in layout order: a "BAY n" stencil in front of the ramp, a yellow-and-black hazard
	band across the ramp's foot, two yellow side lines framing the bay clear of the truck, and a dashed yellow lane
	from behind the spawn strip to the bay's front. Every piece is a thin slab in the depot's local space (y up from
	the floor's top) and no two overlap, so nothing z-fights. DepotBuildSystem lays the plan as non-colliding parts.
	Pure.

	@class DepotMarkingUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)
local DepotTruckVisualConstants = require(ServerScriptService.Features.Depot.Data.DepotTruckVisualConstants)

-- A flat painted slab.
export type Paint = {
	name: string,
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
	table.insert(paints, { name = name, size = size, position = position, color = color })
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
	return { paints = paints, labels = labels }
end

return DepotMarkingUtils
