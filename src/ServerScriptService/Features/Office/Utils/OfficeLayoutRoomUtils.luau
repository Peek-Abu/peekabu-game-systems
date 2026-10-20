--!strict
-- Compact workplace packing reserves the central cross, all four ports and each desk chair.
local Server = game:GetService("ServerScriptService").Features.Office
local Types = require(Server.Data.OfficeTypes)
local Constants = require(Server.Data.OfficeConstants)
local Utils = {}
type Footprint = { x: number, z: number, hx: number, hz: number }
local PILE_SIZE = Vector3.new(4, 1, 4)
local SIZES: { [Types.MarkerKind]: Vector3? } = {
	desk = Constants.DESK_SIZE,
	locker = Constants.LOCKER_SIZE,
	shelf = Constants.SHELF_SIZE,
	counter = Constants.COUNTER_SIZE,
	table = Constants.TABLE_SIZE,
	cabinet = Constants.CABINET_SIZE,
	closet = Constants.CLOSET_SIZE,
	plant = Constants.PLANT_SIZE,
	pile = PILE_SIZE,
	item = Vector3.new(3.6, 1, 3.6),
}
function Utils.markers(room: Types.Room, rng: Random): { Types.Marker }
	local markers: { Types.Marker } = {}
	local occupied: { Footprint } = {}
	local counts: { [string]: number } = {}
	local wall = Constants.WALL_THICKNESS / 2
	local cx, cz = (room.minX + room.maxX) / 2, (room.minZ + room.maxZ) / 2
	local hx, hz = (room.maxX - room.minX) / 2, (room.maxZ - room.minZ) / 2
	local quarter = rng:NextInteger(0, 3)
	local yaw = quarter * math.pi / 2
	if quarter % 2 == 1 then
		hx, hz = hz, hx
	end
	local cos, sin = math.cos(yaw), math.sin(yaw)
	local flip = if rng:NextInteger(0, 1) == 0 then 1 else -1
	local function clear(x: number, z: number, halfX: number, halfZ: number, approach: number?): boolean
		if math.abs(x) + halfX > hx - wall + 0.001 or math.abs(z) + halfZ > hz - wall + 0.001 then
			return false
		end
		if math.abs(x) - halfX < 5 or math.abs(z) - halfZ < 5 then
			return false
		end
		local radius = approach or 7
		for _, door in { { hx, 0 }, { -hx, 0 }, { 0, hz }, { 0, -hz } } do
			if math.abs(x - door[1]) < halfX + radius and math.abs(z - door[2]) < halfZ + radius then
				return false
			end
		end
		for _, other in occupied do
			if math.abs(x - other.x) < halfX + other.hx + 0.25 and math.abs(z - other.z) < halfZ + other.hz + 0.25 then
				return false
			end
		end
		return true
	end
	local function add(kind: Types.MarkerKind, x: number, z: number, facing: number): boolean
		local size = SIZES[kind]
		if size ~= nil then
			local c, s = math.abs(math.cos(facing)), math.abs(math.sin(facing))
			local halfX, halfZ = (size.X * c + size.Z * s) / 2, (size.X * s + size.Z * c) / 2
			local approach = if kind == "item" or kind == "pile" then 5 else 7
			if not clear(x, z, halfX, halfZ, approach) then
				return false
			end
			table.insert(occupied, { x = x, z = z, hx = halfX, hz = halfZ })
		end
		counts[kind] = (counts[kind] or 0) + 1
		table.insert(markers, {
			id = `{room.id}.{kind}.{counts[kind]}`,
			room = room.id,
			kind = kind,
			x = cx + cos * x + sin * z,
			z = cz - sin * x + cos * z,
			rotation = facing + yaw,
		})
		return true
	end
	-- Minimum 30x28 cells fit these essentials in their corners with four physical ports.
	-- A desk (and its chair) that does not fit the room's walls, doors and cross is left out, never moved or shrunk.
	local chairHalf = math.max(Constants.OFFICE_CHAIR_SIZE.X, Constants.OFFICE_CHAIR_SIZE.Z) / 2
	local chairOffset = Constants.DESK_SIZE.Z / 2 + Constants.OFFICE_CHAIR_SIZE.Z / 2 + Constants.OFFICE_CHAIR_GAP
	local deskX, deskZ = -flip * (hx - 1 - Constants.DESK_SIZE.X / 2), -hz + Constants.DESK_SIZE.Z / 2 + wall
	local chairZ = deskZ + chairOffset
	if clear(deskX, chairZ, chairHalf, chairHalf) and add("desk", deskX, deskZ, math.pi) then
		table.insert(occupied, { x = deskX, z = chairZ, hx = chairHalf, hz = chairHalf })
	end
	assert(
		add("counter", flip * (hx - 3.5), -hz + Constants.COUNTER_SIZE.Z / 2 + wall, math.pi),
		"compact room requires an appliance surface"
	)
	assert(
		add("pile", -hx + 2.5, hz - 2.5, 0) and add("pile", hx - 2.5, hz - 2.5, 0),
		"compact room requires two clear pile spots"
	)
	for _, point in { { -7.25, -7.25 }, { 7.25, -7.25 }, { -7.25, 7.25 }, { 7.25, 7.25 } } do
		assert(add("item", point[1], point[2], 0), "compact room requires four clear cargo spots")
	end
	-- Optional fixtures use actual free footprints, rather than shrinking artist geometry.
	local utility: Types.MarkerKind = if room.zone == "kitchenette" or room.zone == "breakRoom"
		then "counter"
		else "table"
	add(utility, flip * (hx - 4.5), hz - 7, 0)
	if room.zone == "storage" or room.zone == "records" then
		add("shelf", hx - Constants.SHELF_SIZE.Z / 2 - wall, hz - 7.5, math.pi / 2)
	elseif room.zone == "training" or room.zone == "office" then
		local x, z = -flip * (hx - 1 - Constants.DESK_SIZE.X / 2), hz - Constants.DESK_SIZE.Z / 2 - wall
		if clear(x, z - chairOffset, chairHalf, chairHalf) and add("desk", x, z, 0) then
			table.insert(occupied, { x = x, z = z - chairOffset, hx = chairHalf, hz = chairHalf })
		end
	end
	local cabinet: Types.MarkerKind = if rng:NextInteger(0, 1) == 0 then "locker" else "cabinet"
	local depth = if cabinet == "locker" then Constants.LOCKER_SIZE.Z else Constants.CABINET_SIZE.Z
	add(cabinet, -flip * (hx - depth / 2 - wall), -hz + 8.5, if flip == 1 then -math.pi / 2 else math.pi / 2)
	add("plant", flip * (hx - 2.1), -hz + 4.5, 0)
	-- High wall dressing occupies its own plane above the rear piles.
	add("board", -flip * (hx - 4), hz - Constants.BOARD_SIZE.Z / 2 - wall, 0)
	for _, x in { -hx + 6, hx - 6 } do
		for _, z in { -hz + 8, hz - 8 } do
			add("item", x, z, 0)
		end
	end
	-- One tall supply cabinet (a secure hiding spot) against a wall, its door to the room, where the room has a clear
	-- stretch of wall for it away from the doors, the piles and the furniture; a small room has none. Sparse: at most
	-- one per room. Placed last, in the space the room has left, so it never displaces anything else.
	local inset = Constants.CLOSET_SIZE.Z / 2 + wall
	local closets: { { number } } = {}
	for _, along in { hx - 7, hx - 9, 10 } do
		-- Not under the notice board (the far wall's -flip end): it has no floor footprint to be kept clear by.
		table.insert(closets, { flip * along, hz - inset, 0 })
		for _, side in { flip, -flip } do
			table.insert(closets, { side * along, -hz + inset, math.pi })
		end
	end
	for _, along in { hz - 7, hz - 9, 10 } do
		for _, side in { 1, -1 } do
			table.insert(closets, { hx - inset, side * along, math.pi / 2 })
			table.insert(closets, { -hx + inset, side * along, -math.pi / 2 })
		end
	end
	for _, candidate in closets do
		if add("closet", candidate[1], candidate[2], candidate[3]) then
			break
		end
	end
	-- More dust spots, up to PILE_SPOTS (a dirty room holds several piles: docs/superpowers/specs/
	-- 2026-10-16-cleanup-crew-gloom-gleam-economy-design.md §3.1). Placed after everything else, on the floor the room
	-- has left, nearest a wall first, so they never displace furniture, loot spots or the supply cabinet. Each keeps a
	-- little more than the usual gap, so float rounding never lands one exactly on another's edge.
	local pileHalf = PILE_SIZE.X / 2
	local spots: { Vector2 } = {}
	local spotX = -hx + 2.5
	while spotX <= hx - 2.5 + 0.001 do
		local spotZ = -hz + 2.5
		while spotZ <= hz - 2.5 + 0.001 do
			table.insert(spots, Vector2.new(spotX, spotZ))
			spotZ += Constants.PILE_SPOT_STEP
		end
		spotX += Constants.PILE_SPOT_STEP
	end
	local function toWall(spot: Vector2): number
		return math.min(hx - math.abs(spot.X), hz - math.abs(spot.Y))
	end
	table.sort(spots, function(a: Vector2, b: Vector2): boolean
		local wallA, wallB = toWall(a), toWall(b)
		if wallA ~= wallB then
			return wallA < wallB
		end
		if a.X ~= b.X then
			return a.X < b.X
		end
		return a.Y < b.Y
	end)
	for _, spot in spots do
		if (counts.pile or 0) >= Constants.PILE_SPOTS then
			break
		end
		if clear(spot.X, spot.Y, pileHalf + 0.05, pileHalf + 0.05, 5) then
			add("pile", spot.X, spot.Y, 0)
		end
	end
	add("patrol", 0, 0, 0)
	return markers
end
return Utils
