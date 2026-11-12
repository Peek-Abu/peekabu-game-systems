local ServerScriptService = game:GetService("ServerScriptService")

local Office = ServerScriptService.Features.Office
local SchoolConstants = require(script.Parent.SchoolConstants)
local SchoolKitRegistry = require(script.Parent.SchoolKitRegistry)
local OfficeConstants = require(Office.Data.OfficeConstants)
local OfficeKitRules = require(Office.Rules.OfficeKitRules)
local OfficeLayoutRules = require(Office.Rules.OfficeLayoutRules)
local OfficeKitUtils = require(Office.Utils.OfficeKitUtils)
local OfficeLayoutUtils = require(Office.Utils.OfficeLayoutUtils)

local FACINGS = { "minZ", "minX", "maxZ", "maxX" }
local LANDMARKS = { gym = true, cafeteria = true, library = true }
-- Each School room type and how many kits it has at least.
local COVERAGE = {
	classroom = 4,
	gym = 1,
	cafeteria = 1,
	library = 1,
	nurse = 1,
	principal = 1,
	lounge = 1,
	bathroom = 1,
	janitor = 1,
	fronthall = 1,
}

-- One placed kit as a whole layout, its truck a point at the room's centre.
local function layoutOf(placement)
	local room = placement.room
	local cx, cz = (room.minX + room.maxX) / 2, (room.minZ + room.maxZ) / 2
	return {
		startRoom = room.id,
		rooms = { room },
		doors = {},
		markers = placement.markers,
		truck = { minX = cx, minZ = cz, maxX = cx, maxZ = cz, clockX = cx, clockZ = cz },
		route = {},
		rest = "",
	}
end

-- The floor footprints of a kit's furniture (wall, desk-top and flat props left out), in its local frame.
local function floorBoxes(kit)
	local boxes = {}
	for _, marker in kit.markers do
		local size = OfficeLayoutUtils.markerSize(marker)
		local art = marker.art
		local raised = marker.kind == "prop"
			and art ~= nil
			and (OfficeConstants.PROP_WALL_HEIGHT[art] ~= nil or OfficeConstants.PROP_DESK_TOP[art] == true)
		if size ~= nil and not raised and not OfficeLayoutUtils.isFlatProp(marker) then
			local angle = marker.rotation or 0
			local c, s = math.abs(math.cos(angle)), math.abs(math.sin(angle))
			local halfX = (size.X * c + size.Z * s) / 2
			local halfZ = (size.X * s + size.Z * c) / 2
			table.insert(boxes, {
				name = `{marker.kind} at ({marker.x}, {marker.z})`,
				minX = marker.x - halfX,
				maxX = marker.x + halfX,
				minZ = marker.z - halfZ,
				maxZ = marker.z + halfZ,
			})
		end
	end
	return boxes
end

local function overlaps(a, b)
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

local function count(kit, kind)
	local n = 0
	for _, marker in kit.markers do
		if marker.kind == kind then
			n += 1
		end
	end
	return n
end

-- Pieces that stand with their back to a wall (the kinds, and the dressing props among the prop markers).
local WALL_BACKED_KINDS = { shelf = true, counter = true, cabinet = true, closet = true }
local WALL_BACKED_PROPS = {
	vending = true,
	schoolVending = true,
	waterCooler = true,
	sofa = true,
	bench = true,
	bleachers = true,
	copier = true,
	planter = true,
}
-- A piece this close to a wall (its footprint's gap to the wall line, less half a wall) stands against it.
local AGAINST = 1.2

-- The wall a marker stands nearest to (its footprint's gap to each wall line, less half a wall), and that gap.
local function nearestWall(kit, marker)
	local size = OfficeLayoutUtils.markerSize(marker)
	local angle = marker.rotation or 0
	local c, s = math.abs(math.cos(angle)), math.abs(math.sin(angle))
	local hx, hz = (size.X * c + size.Z * s) / 2, (size.X * s + size.Z * c) / 2
	local half = OfficeConstants.WALL_THICKNESS / 2
	local gaps = {
		minX = marker.x - hx - half,
		maxX = kit.width - half - (marker.x + hx),
		minZ = marker.z - hz - half,
		maxZ = kit.depth - half - (marker.z + hz),
	}
	local edge, gap = nil, math.huge
	for name, value in gaps do
		if value < gap then
			edge, gap = name, value
		end
	end
	return edge, gap
end

-- The wall a marker's back points at (its front is local -Z turned by its rotation).
local function backWall(marker)
	local angle = marker.rotation or 0
	local bx, bz = math.sin(angle), math.cos(angle)
	if math.abs(bx) > math.abs(bz) then
		return if bx > 0 then "maxX" else "minX"
	end
	return if bz > 0 then "maxZ" else "minZ"
end

return function()
	it("stands every wall piece against a wall with its back to that wall, never side-on or facing it", function()
		for _, kit in SchoolKitRegistry.KITS do
			for _, marker in kit.markers do
				local backed = WALL_BACKED_KINDS[marker.kind] == true
					or (marker.kind == "prop" and marker.art ~= nil and WALL_BACKED_PROPS[marker.art] == true)
				if backed then
					local edge, gap = nearestWall(kit, marker)
					if gap <= AGAINST then
						local label = `{kit.id} {marker.kind}/{marker.art} at ({marker.x}, {marker.z})`
						expect(`{label} back to {backWall(marker)}`).to.equal(`{label} back to {edge}`)
					end
				end
			end
		end
	end)

	it("every kit passes OfficeKitRules", function()
		for _, kit in SchoolKitRegistry.KITS do
			local ok, errors = OfficeKitRules.check(kit)
			expect(`{kit.id}: {table.concat(errors, "; ")}`).to.equal(`{kit.id}: `)
			expect(ok).to.equal(true)
		end
	end)

	it("every kit places as a valid one-room layout in every facing and mirror", function()
		for _, kit in SchoolKitRegistry.KITS do
			for _, facing in FACINGS do
				for _, mirrored in { false, true } do
					local layout = layoutOf(OfficeKitUtils.place(kit, "r", 100, 100, facing, mirrored))
					local ok, errors = OfficeLayoutRules.validate(layout)
					local tag = `{kit.id} {facing} mirrored={mirrored}`
					expect(`{tag}: {table.concat(errors, "; ")}`).to.equal(`{tag}: `)
					expect(ok).to.equal(true)
					for _, marker in layout.markers do
						expect(`{tag} {marker.id} {OfficeLayoutRules.markerFits(layout, marker)}`).to.equal(
							`{tag} {marker.id} true`
						)
					end
				end
			end
		end
	end)

	it("covers every School room type", function()
		for roomType, wanted in COVERAGE do
			local found = #SchoolKitRegistry.ofType(roomType)
			expect(`{roomType} {found >= wanted}`).to.equal(`{roomType} true`)
		end
		for _, kit in SchoolKitRegistry.KITS do
			expect(`{kit.id} {COVERAGE[kit.roomType] ~= nil}`).to.equal(`{kit.id} true`)
		end
		expect(#SchoolKitRegistry.ofType("fronthall")).to.equal(1)
		expect(#SchoolKitRegistry.ofType("pods")).to.equal(0)
	end)

	it("has every kit the deck and the classroom slots name", function()
		for _, id in SchoolConstants.DECK do
			expect(`{id} {SchoolKitRegistry.get(id) ~= nil}`).to.equal(`{id} true`)
		end
		for _, id in SchoolConstants.CLASSROOM_KITS do
			local kit = SchoolKitRegistry.get(id)
			expect(`{id} {kit ~= nil and kit.roomType}`).to.equal(`{id} classroom`)
		end
		for _, roomType in SchoolConstants.LANDMARKS do
			expect(#SchoolKitRegistry.ofType(roomType)).to.equal(1)
		end
		expect(SchoolKitRegistry.get("lounge").roomType).to.equal("lounge")
	end)

	it("ids are unique and get finds them", function()
		local seen = {}
		for _, kit in SchoolKitRegistry.KITS do
			expect(seen[kit.id]).to.equal(nil)
			seen[kit.id] = true
			expect(SchoolKitRegistry.get(kit.id)).to.equal(kit)
		end
		expect(SchoolKitRegistry.get("pods_a")).to.equal(nil)
		expect(SchoolKitRegistry.get("nope")).to.equal(nil)
	end)

	it("keeps rest markers to the teachers' lounge", function()
		for _, kit in SchoolKitRegistry.KITS do
			expect(`{kit.id} {count(kit, "rest") > 0}`).to.equal(`{kit.id} {kit.roomType == "lounge"}`)
		end
	end)

	it("names the art of every desk, so none is dressed as an office desk", function()
		for _, kit in SchoolKitRegistry.KITS do
			for _, marker in kit.markers do
				if marker.kind == "desk" then
					expect(`{kit.id} {marker.x},{marker.z} {marker.art ~= nil}`).to.equal(
						`{kit.id} {marker.x},{marker.z} true`
					)
				end
			end
		end
	end)

	it("gives every room but the front hall a hiding place (a desk or a closet)", function()
		for _, kit in SchoolKitRegistry.KITS do
			if kit.roomType ~= "fronthall" then
				local hides = count(kit, "desk") + count(kit, "closet")
				expect(`{kit.id} hides {hides >= 1}`).to.equal(`{kit.id} hides true`)
			end
		end
	end)

	it("keeps the hiding places as sparse as the Office's: a few per room, the student desks low tables", function()
		-- A classroom hides under its teacher's desk and one big table (or in a closet); its rows or groups of student
		-- desks are low tables (kind table, no hide space), so a classroom stays readable without a grid of hides.
		for _, id in SchoolConstants.CLASSROOM_KITS do
			local kit = SchoolKitRegistry.get(id)
			local hides = count(kit, "desk") + count(kit, "closet")
			expect(`{id} hides {hides >= 1 and hides <= 2}`).to.equal(`{id} hides true`)
			expect(`{id} student desks {count(kit, "table") >= 4}`).to.equal(`{id} student desks true`)
		end
		-- A landmark keeps a few hides, not a hall full of them.
		for _, kit in SchoolKitRegistry.KITS do
			if LANDMARKS[kit.roomType] then
				local hides = count(kit, "desk") + count(kit, "closet")
				expect(`{kit.id} hides {hides >= 2 and hides <= 4}`).to.equal(`{kit.id} hides true`)
			end
		end
		-- No room is a hiding grid: at most four hides in any kit.
		for _, kit in SchoolKitRegistry.KITS do
			local hides = count(kit, "desk") + count(kit, "closet")
			expect(`{kit.id} hides {hides <= 4}`).to.equal(`{kit.id} hides true`)
		end
	end)

	it("sizes a landmark to fit its lattice block with a back aisle, even with jitter", function()
		local jitter = SchoolConstants.LATTICE_JITTER
		local blockWidth = SchoolConstants.LATTICE_STEP_X - SchoolConstants.JUNCTION_MIN - 2 * jitter
		local blockDepth = SchoolConstants.LATTICE_STEP_Z - SchoolConstants.CORRIDOR_WIDE - 2 * jitter
		for _, kit in SchoolKitRegistry.KITS do
			if LANDMARKS[kit.roomType] then
				expect(`{kit.id} width {kit.width <= blockWidth}`).to.equal(`{kit.id} width true`)
				expect(`{kit.id} depth {kit.depth + SchoolConstants.LANDMARK_BACK_AISLE <= blockDepth}`).to.equal(
					`{kit.id} depth true`
				)
				expect(`{kit.id} {kit.width} x {kit.depth}`).to.equal(`{kit.id} 64 x 56`)
				expect(kit.door.kind).to.equal("open")
			end
		end
	end)

	it("sizes every other room for a room slot (a block quarter or the wall band)", function()
		local jitter = SchoolConstants.LATTICE_JITTER
		-- A quarter's run along a main-row hall, and along a side-column hall.
		local alongRow = SchoolConstants.LATTICE_STEP_X / 2 - SchoolConstants.JUNCTION_MIN / 2 - jitter
		local alongColumn = SchoolConstants.LATTICE_STEP_Z / 2 - SchoolConstants.JUNCTION_MIN / 2 - jitter
		local quarterDepth = SchoolConstants.LATTICE_STEP_Z / 2 - SchoolConstants.CORRIDOR_WIDE / 2 - jitter
		for _, kit in SchoolKitRegistry.KITS do
			if not LANDMARKS[kit.roomType] and kit.roomType ~= "fronthall" then
				expect(`{kit.id} width {kit.width <= alongRow}`).to.equal(`{kit.id} width true`)
				expect(`{kit.id} depth {kit.depth <= math.min(SchoolConstants.BAND_DEPTH, quarterDepth)}`).to.equal(
					`{kit.id} depth true`
				)
			end
		end
		-- The deck's rooms and one classroom kit also fit a quarter facing a side hall.
		for _, id in SchoolConstants.DECK do
			expect(`{id} {SchoolKitRegistry.get(id).width <= alongColumn}`).to.equal(`{id} true`)
		end
		expect(SchoolKitRegistry.get("classroom_groups").width <= alongColumn).to.equal(true)
	end)

	it("makes the front hall the loading bay's size and keeps both entrances clear", function()
		local kit = SchoolKitRegistry.ofType("fronthall")[1]
		expect(kit.width).to.equal(OfficeConstants.BAY_WIDTH)
		expect(kit.depth).to.equal(OfficeConstants.BAY_DEPTH)
		expect(count(kit, "patrol")).to.equal(1)
		-- Placed facing maxZ unmirrored, the back wall is the building front (the dock exit at its middle) and the
		-- right wall (local x = width) is the west wall (the lobby exit at its middle).
		local dock = {
			minX = kit.width / 2 - OfficeConstants.OUTSIDE.DOCK_EXIT_WIDTH / 2 - 1,
			maxX = kit.width / 2 + OfficeConstants.OUTSIDE.DOCK_EXIT_WIDTH / 2 + 1,
			minZ = kit.depth - OfficeConstants.OUTSIDE.INSIDE_STEP - 2,
			maxZ = kit.depth,
		}
		local lobby = {
			minX = kit.width - OfficeConstants.OUTSIDE.INSIDE_STEP - 2,
			maxX = kit.width,
			minZ = kit.depth / 2 - SchoolConstants.ENTRANCE_WIDTH / 2 - 1,
			maxZ = kit.depth / 2 + SchoolConstants.ENTRANCE_WIDTH / 2 + 1,
		}
		for _, box in floorBoxes(kit) do
			expect(`{box.name} blocks the dock exit {overlaps(box, dock)}`).to.equal(
				`{box.name} blocks the dock exit false`
			)
			expect(`{box.name} blocks the lobby exit {overlaps(box, lobby)}`).to.equal(
				`{box.name} blocks the lobby exit false`
			)
		end
	end)

	it("gives every door with a leaf the 6.8-stud rough opening", function()
		for _, kit in SchoolKitRegistry.KITS do
			if kit.door.kind ~= "open" then
				expect(`{kit.id} {kit.door.width}`).to.equal(`{kit.id} 6.8`)
			end
		end
	end)

	it("stands every floor piece at least the trim clearance off every wall's plaster", function()
		local trim = OfficeConstants.SHELL.trimClearance
		local face = OfficeConstants.WALL_THICKNESS / 2
		local checked = 0
		for _, kit in SchoolKitRegistry.KITS do
			for _, box in floorBoxes(kit) do
				checked += 1
				local gaps =
					{ box.minX - face, kit.width - face - box.maxX, box.minZ - face, kit.depth - face - box.maxZ }
				for _, gap in gaps do
					expect(`{kit.id} {box.name} gap {gap >= trim - 0.001}`).to.equal(`{kit.id} {box.name} gap true`)
				end
			end
		end
		expect(checked > 40).to.equal(true)
	end)

	it("names a sized art for every prop", function()
		for _, kit in SchoolKitRegistry.KITS do
			for _, marker in kit.markers do
				if marker.kind == "prop" then
					expect(`{kit.id} {marker.art} {OfficeConstants.PROP_SIZES[marker.art] ~= nil}`).to.equal(
						`{kit.id} {marker.art} true`
					)
				end
			end
		end
	end)
end
