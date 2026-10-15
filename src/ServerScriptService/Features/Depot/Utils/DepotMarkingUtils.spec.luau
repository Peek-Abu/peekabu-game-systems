local ServerScriptService = game:GetService("ServerScriptService")

local DepotMarkingUtils = require(script.Parent.DepotMarkingUtils)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)
local DepotTruckVisualConstants = require(ServerScriptService.Features.Depot.Data.DepotTruckVisualConstants)

local LAYOUT = DepotLayoutConstants.LAYOUT
local MARKING = DepotLayoutConstants.MARKING

local function named(pieces, prefix)
	local found = {}
	for _, piece in pieces do
		if string.sub(piece.name, 1, #prefix) == prefix then
			table.insert(found, piece)
		end
	end
	return found
end

local function footprint(piece)
	return piece.position.X - piece.size.X / 2,
		piece.position.X + piece.size.X / 2,
		piece.position.Z - piece.size.Z / 2,
		piece.position.Z + piece.size.Z / 2
end

local function overlaps(a, b)
	local aMinX, aMaxX, aMinZ, aMaxZ = footprint(a)
	local bMinX, bMaxX, bMinZ, bMaxZ = footprint(b)
	local eps = 1e-4
	return aMinX < bMaxX - eps and bMinX < aMaxX - eps and aMinZ < bMaxZ - eps and bMinZ < aMaxZ - eps
end

return function()
	local plan = DepotMarkingUtils.plan(LAYOUT)
	local all = {}
	for _, piece in plan.paints do
		table.insert(all, piece)
	end
	for _, label in plan.labels do
		table.insert(all, label)
	end

	it("stencils BAY 1 / BAY 2 / BAY 3 in front of each truck, in layout order", function()
		expect(#plan.labels).to.equal(#LAYOUT.trucks)
		for index, truck in LAYOUT.trucks do
			local label = plan.labels[index]
			expect(label.text).to.equal(`BAY {index}`)
			expect(label.position.X).to.be.near(truck.x, 1e-6)
			-- In front of the truck (toward the boards and spawns), ahead of the ramp's foot.
			expect(label.position.Z + label.size.Z / 2 <= truck.z - DepotTruckVisualConstants.BACK).to.equal(true)
		end
	end)

	it("lays a yellow-and-black hazard band across each ramp's foot", function()
		for index, truck in LAYOUT.trucks do
			local stripes = named(plan.paints, `Hazard{index}_`)
			expect(#stripes >= 5).to.equal(true)
			local yellow, black = 0, 0
			local minX, maxX = math.huge, -math.huge
			for _, stripe in stripes do
				if stripe.color == MARKING.YELLOW then
					yellow += 1
				elseif stripe.color == MARKING.BLACK then
					black += 1
				end
				local sMinX, sMaxX, _, sMaxZ = footprint(stripe)
				minX = math.min(minX, sMinX)
				maxX = math.max(maxX, sMaxX)
				-- The band ends at the ramp's foot and never runs under the truck.
				expect(sMaxZ <= truck.z - DepotTruckVisualConstants.BACK + 1e-6).to.equal(true)
			end
			expect(yellow > 0 and black > 0).to.equal(true)
			expect(yellow + black).to.equal(#stripes)
			-- At least as wide as the ramp (7 studs), centred on the truck.
			expect(maxX - minX >= 7).to.equal(true)
			expect((minX + maxX) / 2).to.be.near(truck.x, 1e-6)
		end
	end)

	it("lines each bay's sides clear of the truck and draws a lane from the spawn strip to its front", function()
		for index, truck in LAYOUT.trucks do
			local sides = named(plan.paints, `BayLine{index}_`)
			expect(#sides).to.equal(2)
			for _, side in sides do
				expect(math.abs(side.position.X - truck.x) - side.size.X / 2 > DepotTruckVisualConstants.HALF_WIDTH).to.equal(
					true
				)
			end
			local dashes = named(plan.paints, `Lane{index}_`)
			expect(#dashes >= 2).to.equal(true)
			local lowest = math.huge
			for _, dash in dashes do
				expect(dash.position.X).to.be.near(truck.x, 1e-6)
				local _, _, minZ = footprint(dash)
				lowest = math.min(lowest, minZ)
			end
			-- It starts back at the spawn strip (the spawns are at z 26).
			expect(lowest <= LAYOUT.spawns[1].z).to.equal(true)
		end
	end)

	it("keeps every piece thin, just above the floor, and inside it", function()
		local floor = LAYOUT.floor
		for _, piece in all do
			expect(piece.size.Y <= 0.06).to.equal(true)
			local bottom = piece.position.Y - piece.size.Y / 2
			expect(bottom > 0).to.equal(true)
			expect(bottom < 0.05).to.equal(true)
			local minX, maxX, minZ, maxZ = footprint(piece)
			expect(minX >= floor.minX and maxX <= floor.maxX).to.equal(true)
			expect(minZ >= floor.minZ and maxZ <= floor.maxZ).to.equal(true)
		end
	end)

	it("never lays two pieces over each other (no z-fighting)", function()
		for i = 1, #all do
			for j = i + 1, #all do
				if overlaps(all[i], all[j]) then
					error(`{all[i].name} overlaps {all[j].name}`)
				end
			end
		end
	end)
end
