local Server = game:GetService("ServerScriptService").Features.Office
local Constants = require(Server.Data.OfficeConstants)
local Gen = require(script.Parent.OfficeLayoutGenerationUtils)
local Base = require(Server.Data.OfficeLayoutConstants).LAYOUT
local Dressing = require(script.Parent.OfficeHallDressingUtils)
local Lighting = require(script.Parent.OfficeLightingUtils)
local LayoutUtils = require(script.Parent.OfficeLayoutUtils)
local Rules = require(Server.Rules.OfficeLayoutRules)

local SEEDS = 20
local HALF_WALL = Constants.WALL_THICKNESS / 2
local FACE_YAW = { minX = -math.pi / 2, maxX = math.pi / 2, minZ = math.pi, maxZ = 0 }
local COLLIDABLE = { planter = true, sofa = true, waterCooler = true }

local cache = {}
local function layoutFor(seed)
	local layout = cache[seed]
	if layout == nil then
		layout = Gen.generate(Base, seed)
		cache[seed] = layout
	end
	return layout
end

local function roomsById(layout)
	local byId = {}
	for _, room in layout.rooms do
		byId[room.id] = room
	end
	return byId
end

local function extents(marker)
	local size = Constants.PROP_SIZES[marker.art]
	local angle = marker.rotation or 0
	local c, s = math.abs(math.cos(angle)), math.abs(math.sin(angle))
	return (size.X * c + size.Z * s) / 2, (size.X * s + size.Z * c) / 2
end

-- Every dressing prop of every hallway room: { marker, room }.
local function hallProps(layout)
	local byId = roomsById(layout)
	local list = {}
	for _, marker in layout.markers do
		local room = byId[marker.room]
		if marker.kind == "prop" and room ~= nil and room.zone == "hallway" then
			table.insert(list, { marker = marker, room = room })
		end
	end
	return list
end

-- The wall a collidable stands on, its gap to that wall's inner face, and how far its footprint reaches off the face.
local function wallAndReach(marker, room)
	local hx, hz = extents(marker)
	local best, bestEdge = math.huge, nil
	local distances = {
		minX = marker.x - hx - (room.minX + HALF_WALL),
		maxX = room.maxX - HALF_WALL - (marker.x + hx),
		minZ = marker.z - hz - (room.minZ + HALF_WALL),
		maxZ = room.maxZ - HALF_WALL - (marker.z + hz),
	}
	for edge, gap in distances do
		if gap < best then
			best, bestEdge = gap, edge
		end
	end
	local reach = if bestEdge == "minX" or bestEdge == "maxX" then hx * 2 + best else hz * 2 + best
	return bestEdge, best, reach
end

local function openingRects(layout, room)
	local rects = {}
	for _, edge in { "minX", "maxX", "minZ", "maxZ" } do
		local horizontal = edge == "minZ" or edge == "maxZ"
		local wall = room[edge]
		for _, span in LayoutUtils.openingsOn(layout, room, edge) do
			local from, to = span[1] - Constants.SHELL.casing, span[2] + Constants.SHELL.casing
			if horizontal then
				table.insert(rects, { minX = from, maxX = to, minZ = wall - HALF_WALL, maxZ = wall + HALF_WALL })
			else
				table.insert(rects, { minX = wall - HALF_WALL, maxX = wall + HALF_WALL, minZ = from, maxZ = to })
			end
		end
	end
	return rects
end

local function distanceToRect(marker, rect)
	local hx, hz = extents(marker)
	local dx = math.max(rect.minX - (marker.x + hx), (marker.x - hx) - rect.maxX, 0)
	local dz = math.max(rect.minZ - (marker.z + hz), (marker.z - hz) - rect.maxZ, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function signature(layout)
	local parts = {}
	for _, entry in hallProps(layout) do
		local m = entry.marker
		table.insert(parts, `{m.id}:{m.art}:{m.x}:{m.z}:{m.rotation}`)
	end
	return table.concat(parts, ";")
end

return function()
	describe("OfficeHallDressingUtils", function()
		it("keeps the lane clear: collidables hug their wall", function()
			local collidables = 0
			for seed = 1, SEEDS do
				for _, entry in hallProps(layoutFor(seed)) do
					local marker = entry.marker
					if COLLIDABLE[marker.art] then
						collidables += 1
						local _, gap, reach = wallAndReach(marker, entry.room)
						expect(gap <= Dressing.MAX_WALL_GAP + 0.001).to.equal(true)
						expect(reach <= Dressing.MAX_REACH + 0.001).to.equal(true)
					end
				end
			end
			expect(collidables > 0).to.equal(true)
		end)

		it("keeps 3 studs from every door casing and junction mouth", function()
			for seed = 1, SEEDS do
				local layout = layoutFor(seed)
				for _, entry in hallProps(layout) do
					if COLLIDABLE[entry.marker.art] then
						for _, rect in openingRects(layout, entry.room) do
							expect(distanceToRect(entry.marker, rect) >= Dressing.OPENING_CLEAR - 0.001).to.equal(true)
						end
					end
				end
			end
		end)

		it("keeps collidables 12 apart along a wall and clear of patrol points", function()
			for seed = 1, SEEDS do
				local layout = layoutFor(seed)
				local onWall = {}
				for _, entry in hallProps(layout) do
					local marker = entry.marker
					if COLLIDABLE[marker.art] then
						local edge = wallAndReach(marker, entry.room)
						local key = `{entry.room.id}.{edge}`
						onWall[key] = onWall[key] or {}
						table.insert(onWall[key], marker)
						for _, patrol in layout.markers do
							if patrol.kind == "patrol" then
								local hx, hz = extents(marker)
								local clear = math.abs(patrol.x - marker.x) >= hx + Dressing.PATROL_CLEAR - 0.001
									or math.abs(patrol.z - marker.z) >= hz + Dressing.PATROL_CLEAR - 0.001
								expect(clear).to.equal(true)
							end
						end
					end
				end
				for _, list in onWall do
					for i = 1, #list do
						for j = i + 1, #list do
							local apart = math.max(math.abs(list[i].x - list[j].x), math.abs(list[i].z - list[j].z))
							expect(apart >= Dressing.COLLIDABLE_SPACING - 0.001).to.equal(true)
						end
					end
				end
			end
		end)

		it("hangs a sconce on each free sconce spot", function()
			for seed = 1, SEEDS do
				local layout = layoutFor(seed)
				local sconces = 0
				for _, room in layout.rooms do
					if room.zone == "hallway" then
						local rects = openingRects(layout, room)
						for _, spot in Lighting.sconceSpots(room) do
							local free = true
							for _, rect in rects do
								local probe = { x = spot.x, z = spot.z, art = "sconce", rotation = FACE_YAW[spot.side] }
								if distanceToRect(probe, rect) < Dressing.SCONCE_DOOR_CLEAR then
									free = false
								end
							end
							local found = false
							for _, marker in layout.markers do
								if
									marker.room == room.id
									and marker.art == "sconce"
									and math.abs(marker.x - spot.x) < 1.5
									and math.abs(marker.z - spot.z) < 1.5
								then
									found = true
								end
							end
							if free then
								sconces += 1
								expect(found).to.equal(true)
							end
						end
					end
				end
				expect(sconces > 0).to.equal(true)
			end
		end)

		it("gives the same seed the same dressing", function()
			for seed = 1, 5 do
				expect(signature(Gen.generate(Base, seed))).to.equal(signature(Gen.generate(Base, seed)))
			end
			local a, b = signature(layoutFor(1)), signature(layoutFor(2))
			expect(a ~= b).to.equal(true)
		end)

		it("dresses a bare hall without touching a door", function()
			local room = { id = "h1", name = "h", zone = "hallway", minX = 0, maxX = 60, minZ = 0, maxZ = 10 }
			local other = { id = "k1", name = "k", minX = 20, maxX = 40, minZ = 10, maxZ = 30 }
			local layout = {
				rooms = { room, other },
				doors = { { a = "h1", b = "k1", x = 30, z = 10, width = 6, kind = "solid" } },
				markers = {},
				facades = {},
			}
			local markers = Dressing.dress(room, layout, Random.new(7))
			expect(#markers > 0).to.equal(true)
			for _, marker in markers do
				expect(marker.kind).to.equal("prop")
				expect(marker.room).to.equal("h1")
				expect(Constants.PROP_SIZES[marker.art] ~= nil).to.equal(true)
			end
		end)

		it("keeps every generated layout valid with dressing", function()
			for seed = 1, SEEDS do
				local ok, errors = Rules.validate(layoutFor(seed))
				expect(ok).to.equal(true)
				expect(#errors).to.equal(0)
			end
		end)
	end)
end
