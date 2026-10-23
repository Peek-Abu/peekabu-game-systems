local ServerScriptService = game:GetService("ServerScriptService")

local OfficeConstants = require(script.Parent.OfficeConstants)
local OfficeKitRegistry = require(script.Parent.OfficeKitRegistry)
local OfficeKitRules = require(ServerScriptService.Features.Office.Rules.OfficeKitRules)
local OfficeLayoutRules = require(ServerScriptService.Features.Office.Rules.OfficeLayoutRules)
local OfficeKitUtils = require(ServerScriptService.Features.Office.Utils.OfficeKitUtils)

local ROOM_TYPES = { "pods", "conference", "breakout", "storage", "server", "reception" }
local FACINGS = { "minZ", "minX", "maxZ", "maxX" }

-- Per kit: the dressing props it has at least (art -> count) and the art each restyled furniture kind carries.
-- Boards are always corkboards and shelves shelves unless the kit says otherwise (a server room's are racks).
local DRESSING = {
	pods_a = { props = { copier = 1, planter = 1, wasteBin = 2, artFrame = 1, partition = 2 }, art = {} },
	pods_b = { props = { waterCooler = 1, wasteBin = 1, deskPlant = 2 }, art = {} },
	conference_a = {
		props = { wallScreen = 1, artFrame = 1, planter = 1 },
		art = { table = "conferenceTable" },
	},
	conference_b = { props = { wallScreen = 1, artFrame = 1 }, art = { table = "conferenceTable" } },
	breakout_a = {
		props = { sofa = 1, vending = 1, waterCooler = 1, floorLamp = 1, wallClock = 1 },
		art = { table = "breakTable", counter = "kitchenCounter" },
	},
	storage_a = { props = { wasteBin = 1, sconce = 1 }, art = {} },
	server_a = { props = { sconce = 1, wasteBin = 1 }, art = { shelf = "serverRack" } },
	reception_a = {
		props = { sofa = 1, planter = 2, artFrame = 1, wallClock = 1 },
		art = { counter = "receptionDesk" },
	},
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
		expect(#OfficeKitRegistry.KITS).to.equal(8)
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
