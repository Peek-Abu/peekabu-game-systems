local ServerScriptService = game:GetService("ServerScriptService")

local OfficeConstants = require(script.Parent.OfficeConstants)
local OfficeKitRegistry = require(script.Parent.OfficeKitRegistry)
local OfficeKitRules = require(ServerScriptService.Features.Office.Rules.OfficeKitRules)
local OfficeLayoutRules = require(ServerScriptService.Features.Office.Rules.OfficeLayoutRules)
local OfficeKitUtils = require(ServerScriptService.Features.Office.Utils.OfficeKitUtils)
local OfficeLayoutUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutUtils)

local ROOM_TYPES = { "pods", "conference", "breakout", "storage", "server", "reception" }
local FACINGS = { "minZ", "minX", "maxZ", "maxX" }

-- Per kit: the dressing props it has at least (art -> count) and the art each restyled furniture kind carries.
-- Boards are always corkboards and shelves shelves unless the kit says otherwise (a server room's are racks).
local DRESSING = {
	pods_a = {
		props = {
			partition = 6,
			deskPlant = 6,
			column = 2,
			rug = 1,
			copier = 1,
			planter = 2,
			windowBay = 1,
			wallClock = 1,
			artFrame = 1,
			wasteBin = 1,
		},
		art = {},
	},
	pods_b = { props = { partition = 4, deskPlant = 4, rug = 1, waterCooler = 1, planter = 1 }, art = {} },
	conference_a = {
		props = { wallScreen = 1, artFrame = 1, planter = 1 },
		art = { table = "conferenceTable" },
	},
	conference_b = { props = { wallScreen = 1, artFrame = 1, planter = 1 }, art = { table = "conferenceTable" } },
	breakout_a = {
		props = {
			sofa = 2,
			rug = 1,
			vending = 1,
			waterCooler = 1,
			planter = 1,
			floorLamp = 1,
			artFrame = 1,
			wallClock = 1,
		},
		art = { table = "breakTable", counter = "kitchenCounter" },
	},
	storage_a = { props = { sconce = 1 }, art = {} },
	server_a = { props = { sconce = 2, wasteBin = 1 }, art = { shelf = "serverRack" } },
	reception_a = {
		props = { receptionGlow = 1, rug = 1, sofa = 1, floorLamp = 1, planter = 4, artFrame = 1, wallClock = 1 },
		art = { counter = "receptionDesk", table = "breakTable" },
	},
}
-- The spike's room sizes (width along the front wall x depth into the room).
local SIZES = {
	pods_a = { 60, 44 },
	pods_b = { 44, 32 },
	conference_a = { 32, 24 },
	conference_b = { 22, 18 },
	breakout_a = { 32, 26 },
	server_a = { 20, 18 },
	storage_a = { 12, 12 },
	reception_a = { 28, 28 },
}
-- Pile and item markers per 100 square studs each room type had before the kits grew to the spike's sizes (its kits'
-- markers over its kits' floor), so the contract roll holds with fewer, bigger rooms.
local DENSITY = {
	pods = { piles = 16 / 2772, items = 7 / 2772 },
	conference = { piles = 11 / 1164, items = 3 / 1164 },
	breakout = { piles = 5 / 780, items = 3 / 780 },
	storage = { piles = 5 / 288, items = 1 / 288 },
	server = { piles = 6 / 672, items = 2 / 672 },
	reception = { piles = 6 / 1080, items = 2 / 1080 },
}
local DEFAULT_ART = { board = "corkboard", shelf = "shelf" }

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

return function()
	it("every kit passes OfficeKitRules", function()
		for _, kit in OfficeKitRegistry.KITS do
			local ok, errors = OfficeKitRules.check(kit)
			expect(`{kit.id}: {table.concat(errors, "; ")}`).to.equal(`{kit.id}: `)
			expect(ok).to.equal(true)
		end
	end)

	it("every kit places as a valid one-room layout in every facing and mirror", function()
		for _, kit in OfficeKitRegistry.KITS do
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

	it("keeps the reception's wall dressing off the entrance facade the generator hangs on its back wall", function()
		local kit = OfficeKitRegistry.get("reception_a")
		for _, mirrored in { false, true } do
			local placement = OfficeKitUtils.place(kit, "reception1", 100, 100, "maxX", mirrored)
			local layout = layoutOf(placement)
			-- The generator's entrance: 12 wide, centred on the room's minX wall (the kit's back wall).
			layout.facades = {
				{
					room = "reception1",
					x = placement.room.minX,
					z = (placement.room.minZ + placement.room.maxZ) / 2,
					width = 12,
					kind = "entrance",
				},
			}
			local ok, errors = OfficeLayoutRules.validate(layout)
			expect(`mirrored={mirrored}: {table.concat(errors, "; ")}`).to.equal(`mirrored={mirrored}: `)
			expect(ok).to.equal(true)
		end
	end)

	it("kits match the spike's sizes", function()
		for id, size in SIZES do
			local kit = OfficeKitRegistry.get(id)
			expect(`{id} {kit ~= nil}`).to.equal(`{id} true`)
			expect(`{id} {kit.width} x {kit.depth}`).to.equal(`{id} {size[1]} x {size[2]}`)
		end
		for _, kit in OfficeKitRegistry.KITS do
			expect(`{kit.id} sized {SIZES[kit.id] ~= nil}`).to.equal(`{kit.id} sized true`)
		end
	end)

	it("pods_a holds 12 desks, pods_b 8", function()
		for id, wanted in { pods_a = 12, pods_b = 8 } do
			local desks = 0
			for _, marker in OfficeKitRegistry.get(id).markers do
				if marker.kind == "desk" then
					desks += 1
				end
			end
			expect(`{id} {desks}`).to.equal(`{id} {wanted}`)
		end
	end)

	it("has no pods_c", function()
		expect(OfficeKitRegistry.get("pods_c")).to.equal(nil)
	end)

	it("gives every door with a leaf the 6.8-stud rough opening, and keeps glass beside it", function()
		for _, kit in OfficeKitRegistry.KITS do
			if kit.door.kind ~= "open" then
				expect(`{kit.id} {kit.door.width}`).to.equal(`{kit.id} 6.8`)
			end
			local glass = kit.glass
			if glass ~= nil then
				local from, to = kit.door.offset - kit.door.width / 2, kit.door.offset + kit.door.width / 2
				expect(`{kit.id} glass clear of the door {glass.from >= to or glass.to <= from}`).to.equal(
					`{kit.id} glass clear of the door true`
				)
			end
		end
	end)

	it("keeps each kit's pile and item density at least its room type's old one", function()
		for _, kit in OfficeKitRegistry.KITS do
			local piles, items = 0, 0
			for _, marker in kit.markers do
				if marker.kind == "pile" then
					piles += 1
				elseif marker.kind == "item" then
					items += 1
				end
			end
			local area = kit.width * kit.depth
			local wanted = DENSITY[kit.roomType]
			expect(`{kit.id} piles {piles >= wanted.piles * area}`).to.equal(`{kit.id} piles true`)
			expect(`{kit.id} items {items >= wanted.items * area}`).to.equal(`{kit.id} items true`)
		end
	end)

	it("covers the lean set", function()
		for _, roomType in ROOM_TYPES do
			expect(#OfficeKitRegistry.ofType(roomType) > 0).to.equal(true)
		end
		expect(#OfficeKitRegistry.ofType("reception")).to.equal(1)
		expect(#OfficeKitRegistry.ofType("server") >= 1).to.equal(true)
		expect(#OfficeKitRegistry.ofType("breakout") >= 1).to.equal(true)
	end)

	it("keeps rest markers to breakout kits", function()
		for _, kit in OfficeKitRegistry.KITS do
			local hasRest = false
			for _, marker in kit.markers do
				if marker.kind == "rest" then
					hasRest = true
				end
			end
			expect(hasRest).to.equal(kit.roomType == "breakout")
		end
	end)

	it("ids are unique and get finds them", function()
		local seen = {}
		for _, kit in OfficeKitRegistry.KITS do
			expect(seen[kit.id]).to.equal(nil)
			seen[kit.id] = true
			expect(OfficeKitRegistry.get(kit.id)).to.equal(kit)
		end
		expect(OfficeKitRegistry.get("nope")).to.equal(nil)
	end)

	it("dresses every kit with at least its listed props", function()
		for _, kit in OfficeKitRegistry.KITS do
			local wanted = DRESSING[kit.id]
			expect(`{kit.id} listed: {wanted ~= nil}`).to.equal(`{kit.id} listed: true`)
			local counts = {}
			for _, marker in kit.markers do
				if marker.kind == "prop" then
					expect(OfficeConstants.PROP_SIZES[marker.art] ~= nil).to.equal(true)
					counts[marker.art] = (counts[marker.art] or 0) + 1
				end
			end
			for art, count in wanted.props do
				expect(`{kit.id} {art} {(counts[art] or 0) >= count}`).to.equal(`{kit.id} {art} true`)
			end
		end
		expect(#OfficeKitRegistry.ofType("pods") >= 2).to.equal(true)
	end)

	it("gives every restyled furniture marker its art", function()
		for _, kit in OfficeKitRegistry.KITS do
			local overrides = DRESSING[kit.id].art
			for _, marker in kit.markers do
				local expected = overrides[marker.kind] or DEFAULT_ART[marker.kind]
				if
					marker.kind == "table"
					or marker.kind == "counter"
					or marker.kind == "shelf"
					or marker.kind == "board"
				then
					expect(`{kit.id} {marker.kind} {marker.art}`).to.equal(`{kit.id} {marker.kind} {expected}`)
				end
			end
		end
	end)

	it("stands every floor piece (and the window bay) at least the trim clearance off every wall's plaster", function()
		local trim = OfficeConstants.SHELL.trimClearance
		local checked = 0
		for _, kit in OfficeKitRegistry.KITS do
			for index, marker in kit.markers do
				local size = OfficeLayoutUtils.markerSize(marker)
				local art = marker.art
				local aboveRail = marker.kind == "prop"
					and art ~= nil
					and OfficeConstants.PROP_WALL_HEIGHT[art] ~= nil
					and art ~= "windowBay"
				local skipped = size == nil
					or aboveRail
					or OfficeConstants.PROP_DESK_TOP[art or ""] == true
					or OfficeLayoutUtils.isFlatProp(marker)
				if not skipped then
					checked += 1
					local angle = marker.rotation or 0
					local c, s = math.abs(math.cos(angle)), math.abs(math.sin(angle))
					local halfX = (size.X * c + size.Z * s) / 2
					local halfZ = (size.X * s + size.Z * c) / 2
					local face = OfficeConstants.WALL_THICKNESS / 2
					local gaps = {
						marker.x - halfX - face,
						kit.width - face - (marker.x + halfX),
						marker.z - halfZ - face,
						kit.depth - face - (marker.z + halfZ),
					}
					for _, gap in gaps do
						expect(`{kit.id} {marker.kind} {index} gap {gap >= trim - 0.001}`).to.equal(
							`{kit.id} {marker.kind} {index} gap true`
						)
					end
				end
			end
		end
		expect(checked > 40).to.equal(true)
	end)

	it("keeps desk-top props on a desk and wall props against a wall", function()
		for _, kit in OfficeKitRegistry.KITS do
			for _, marker in kit.markers do
				if marker.kind == "prop" and OfficeConstants.PROP_DESK_TOP[marker.art] then
					local onDesk = false
					for _, other in kit.markers do
						if other.kind == "desk" and other.x == marker.x and other.z == marker.z then
							onDesk = true
						end
					end
					expect(`{kit.id} {marker.art} on desk {onDesk}`).to.equal(`{kit.id} {marker.art} on desk true`)
				end
			end
		end
	end)
end
