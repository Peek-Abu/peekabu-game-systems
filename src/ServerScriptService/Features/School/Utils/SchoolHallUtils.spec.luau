local ServerScriptService = game:GetService("ServerScriptService")

local SchoolHallUtils = require(script.Parent.SchoolHallUtils)
local SchoolConstants = require(ServerScriptService.Features.School.Data.SchoolConstants)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeLayoutRules = require(ServerScriptService.Features.Office.Rules.OfficeLayoutRules)

-- A lone wide hall (horizontal or not) with one doorway on a long wall, as a layout.
local function hallLayout(horizontal)
	local room = if horizontal
		then { id = "hall", name = "Hall", minX = 0, maxX = 66, minZ = 0, maxZ = 14, zone = "hallway" }
		else { id = "hall", name = "Hall", minX = 0, maxX = 14, minZ = 0, maxZ = 66, zone = "hallway" }
	local side = { id = "side", name = "Side", minX = 0, maxX = 0, minZ = 0, maxZ = 0 }
	if horizontal then
		side.minX, side.maxX, side.minZ, side.maxZ = 20, 50, -20, 0
	else
		side.minX, side.maxX, side.minZ, side.maxZ = -20, 0, 20, 50
	end
	local door = if horizontal
		then { a = "side", b = "hall", x = 36, z = 0, width = 6.8, kind = "solid" }
		else { a = "side", b = "hall", x = 0, z = 36, width = 6.8, kind = "solid" }
	return {
		startRoom = "hall",
		rooms = { room, side },
		doors = { door },
		markers = {},
		truck = { minX = 5, maxX = 5, minZ = 5, maxZ = 5, clockX = 5, clockZ = 5 },
		route = {},
		rest = "",
	},
		room,
		door
end

return function()
	describe("School hall furnishing", function()
		it("puts a junction's patrol point at its centre", function()
			local marker = SchoolHallUtils.patrolPoint({
				id = "hallJ2_1",
				name = "Hall",
				minX = 0,
				maxX = 20,
				minZ = 10,
				maxZ = 30,
			})
			expect(marker.id).to.equal("hallJ2_1.patrol.1")
			expect(marker.kind).to.equal("patrol")
			expect(marker.room).to.equal("hallJ2_1")
			expect(marker.x).to.equal(10)
			expect(marker.z).to.equal(20)
		end)

		it("stands locker banks against both long walls, facing in, staggered, clear of the doorway", function()
			for _, horizontal in { true, false } do
				local layout, room, door = hallLayout(horizontal)
				local lockers = SchoolHallUtils.lockers(layout, room)
				expect(#lockers > 0).to.equal(true)
				expect(#lockers % SchoolConstants.LOCKER_BANK).to.equal(0)
				local inset = OfficeConstants.WALL_THICKNESS / 2
					+ OfficeConstants.SHELL.trimClearance
					+ OfficeConstants.LOCKER_SIZE.Z / 2
				local firstOn = {}
				for _, marker in lockers do
					table.insert(layout.markers, marker)
				end
				for _, marker in lockers do
					local tag = `horizontal={horizontal} {marker.id}`
					expect(marker.kind).to.equal("locker")
					expect(marker.room).to.equal("hall")
					local across = if horizontal then marker.z else marker.x
					local along = if horizontal then marker.x else marker.z
					local onMin = math.abs(across - inset) < 1e-6
					local onMax = math.abs(across - (14 - inset)) < 1e-6
					expect(`{tag} on a wall {onMin or onMax}`).to.equal(`{tag} on a wall true`)
					local yaw = if horizontal
						then (if onMin then math.pi else 0)
						else (if onMin then -math.pi / 2 else math.pi / 2)
					expect(marker.rotation).to.equal(yaw)
					expect(`{tag} fits {OfficeLayoutRules.markerFits(layout, marker)}`).to.equal(`{tag} fits true`)
					if onMin then
						local centre = if horizontal then door.x else door.z
						local clear = math.abs(along - centre) - door.width / 2 - OfficeConstants.LOCKER_SIZE.X / 2
						expect(`{tag} clear {clear >= SchoolConstants.LOCKER_CLEAR}`).to.equal(`{tag} clear true`)
					end
					local wall = if onMin then "min" else "max"
					firstOn[wall] = math.min(firstOn[wall] or math.huge, along)
				end
				-- The far wall's banks start half a spacing further along than the near wall's.
				expect(firstOn.max - firstOn.min).to.equal(SchoolConstants.LOCKER_SPACING / 2)
			end
		end)

		it(
			"walks Harlow's loop from the front junction, into the front hall and back once after the first visit",
			function()
				local function room(id)
					return { id = id, name = id, minX = 0, maxX = 1, minZ = 0, maxZ = 1 }
				end
				local function patrol(id)
					return { id = `{id}.patrol.1`, room = id, kind = "patrol", x = 0, z = 0 }
				end
				local layout = {
					startRoom = "bay",
					rooms = { room("bay"), room("J"), room("S"), room("A"), room("B") },
					doors = {
						{ a = "bay", b = "J", x = 0, z = 0, width = 10 },
						{ a = "J", b = "S", x = 0, z = 0, width = 10 },
						{ a = "A", b = "S", x = 0, z = 0, width = 6.8 },
						{ a = "B", b = "S", x = 0, z = 0, width = 6.8 },
					},
					markers = { patrol("bay"), patrol("J"), patrol("A"), patrol("B") },
					truck = { minX = 0, maxX = 0, minZ = 0, maxZ = 0, clockX = 0, clockZ = 0 },
					route = {},
					rest = "",
				}
				local route = SchoolHallUtils.route(layout, "J")
				expect(table.concat(route, " ")).to.equal(
					"J.patrol.1 bay.patrol.1 J.patrol.1 A.patrol.1 B.patrol.1 J.patrol.1"
				)
			end
		)
	end)
end
