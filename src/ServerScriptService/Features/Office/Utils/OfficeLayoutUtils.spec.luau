local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeLayoutUtils = require(script.Parent.OfficeLayoutUtils)
local OfficeLayoutRules = require(ServerScriptService.Features.Office.Rules.OfficeLayoutRules)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local HideHugFormulas = require(ReplicatedStorage.Shared.Features.Hide.Utils.HideHugFormulas)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)

local LAYOUT = OfficeLayoutConstants.LAYOUT
local ROOM = { id = "r", name = "R", minX = 0, minZ = 0, maxX = 20, maxZ = 10 }
local TRUCK = { minX = 0, minZ = 0, maxX = 1, maxZ = 1, clockX = 0, clockZ = 0 }

return function()
	describe("furniture free space", function()
		it("leaves a full-size hider room under a desk and a break table on every axis", function()
			for kind, size in { desk = OfficeConstants.DESK_SIZE, table = OfficeConstants.TABLE_SIZE } do
				local free = HideHugFormulas.freeSize(HideConstants.FURNITURE[kind].free, size)
				expect(free.X >= HideConstants.HUG_FREE_MIN.X).to.equal(true)
				expect(free.Y >= HideConstants.HUG_FREE_MIN.Y).to.equal(true)
				expect(free.Z >= HideConstants.HUG_FREE_MIN.Z).to.equal(true)
			end
		end)
	end)

	describe("dropUnfit", function()
		local function office(markers)
			return {
				startRoom = "r",
				rooms = { { id = "r", name = "R", minX = 0, minZ = 0, maxX = 40, maxZ = 10 } },
				doors = {},
				markers = markers,
				truck = TRUCK,
			}
		end

		it("removes a desk that crosses a wall and counts it", function()
			local layout = office({
				{ id = "r.desk.1", room = "r", kind = "desk", x = 30, z = 5, rotation = 0 },
				{ id = "r.desk.2", room = "r", kind = "desk", x = 2, z = 5, rotation = 0 },
			})
			local kept, dropped = OfficeLayoutUtils.dropUnfit(layout, OfficeLayoutRules)
			expect(dropped).to.equal(1)
			expect(#kept.markers).to.equal(1)
			expect(kept.markers[1].id).to.equal("r.desk.1")
			expect(kept.markers[1].x).to.equal(30)
			expect(#layout.markers).to.equal(2)
		end)

		it("returns a layout where everything fits unchanged", function()
			local layout = office({
				{ id = "r.desk.1", room = "r", kind = "desk", x = 30, z = 5, rotation = 0 },
				{ id = "r.table.1", room = "r", kind = "table", x = 8, z = 5, rotation = 0 },
				{ id = "r.pile.1", room = "r", kind = "pile", x = 20, z = 8 },
			})
			local kept, dropped = OfficeLayoutUtils.dropUnfit(layout, OfficeLayoutRules)
			expect(dropped).to.equal(0)
			expect(kept).to.equal(layout)
		end)

		it("keeps a desk beside a counter and a cabinet that validate accepts", function()
			-- Desk half-width 4.125 + counter half-width 3 = 7.125 < 9 apart; cabinet 0.95 + 4.125 < 6 apart.
			local layout = office({
				{ id = "r.desk.1", room = "r", kind = "desk", x = 20, z = 5, rotation = 0 },
				{ id = "r.counter.1", room = "r", kind = "counter", x = 29.2, z = 5, rotation = 0 },
				{ id = "r.cabinet.1", room = "r", kind = "cabinet", x = 14, z = 5, rotation = 0 },
			})
			local valid = OfficeLayoutRules.validate(layout)
			expect(valid).to.equal(true)
			local kept, dropped = OfficeLayoutUtils.dropUnfit(layout, OfficeLayoutRules)
			expect(dropped).to.equal(0)
			expect(kept).to.equal(layout)
		end)

		it("drops a table that crowds loot but keeps the loot and the other furniture", function()
			local layout = office({
				{ id = "r.table.1", room = "r", kind = "table", x = 10, z = 5, rotation = 0 },
				{ id = "r.item.1", room = "r", kind = "item", x = 10, z = 8 },
				{ id = "r.locker.1", room = "r", kind = "locker", x = 36, z = 8, rotation = 0 },
			})
			local kept, dropped = OfficeLayoutUtils.dropUnfit(layout, OfficeLayoutRules)
			expect(dropped).to.equal(1)
			expect(#kept.markers).to.equal(2)
			expect(OfficeLayoutUtils.marker(kept, "r.table.1")).to.equal(nil)
		end)
	end)

	describe("depths", function()
		it("counts doors from the loading bay", function()
			local depths = OfficeLayoutUtils.depths(LAYOUT)
			expect(depths.bay).to.equal(0)
			expect(depths.lobby).to.equal(1)
			expect(depths.open).to.equal(1)
			expect(depths.breakRoom).to.equal(2)
			expect(depths.manager).to.equal(2)
			expect(depths.server).to.equal(2)
			expect(depths.archive).to.equal(2)
		end)

		it("leaves an unreachable room out", function()
			local depths = OfficeLayoutUtils.depths({
				startRoom = "a",
				rooms = {},
				doors = { { a = "a", b = "b", x = 0, z = 0, width = 6 } },
				markers = {},
				truck = TRUCK,
			})
			expect(depths.b).to.equal(1)
			expect(depths.c).to.equal(nil)
		end)
	end)

	describe("surfaceTopY", function()
		it("reports the furniture top for surface spots and nil for floor spots", function()
			expect(OfficeLayoutUtils.surfaceTopY("counter")).to.equal(OfficeConstants.COUNTER_SIZE.Y)
			expect(OfficeLayoutUtils.surfaceTopY("table")).to.equal(OfficeConstants.TABLE_SIZE.Y)
			expect(OfficeLayoutUtils.surfaceTopY("cabinet")).to.equal(OfficeConstants.CABINET_SIZE.Y)
			expect(OfficeLayoutUtils.surfaceTopY("item")).to.equal(nil)
			expect(OfficeLayoutUtils.surfaceTopY("desk")).to.equal(nil)
			expect(OfficeLayoutUtils.surfaceTopY("pile")).to.equal(nil)
		end)
	end)

	describe("doorEdge", function()
		it("finds the wall a door sits on", function()
			expect(OfficeLayoutUtils.doorEdge(ROOM, { a = "r", b = "s", x = 10, z = 0, width = 4 })).to.equal("minZ")
			expect(OfficeLayoutUtils.doorEdge(ROOM, { a = "r", b = "s", x = 10, z = 10, width = 4 })).to.equal("maxZ")
			expect(OfficeLayoutUtils.doorEdge(ROOM, { a = "r", b = "s", x = 0, z = 5, width = 4 })).to.equal("minX")
			expect(OfficeLayoutUtils.doorEdge(ROOM, { a = "r", b = "s", x = 20, z = 5, width = 4 })).to.equal("maxX")
		end)

		it("returns nil for a door off the walls or wider than its wall", function()
			expect(OfficeLayoutUtils.doorEdge(ROOM, { a = "r", b = "s", x = 10, z = 5, width = 4 })).to.equal(nil)
			expect(OfficeLayoutUtils.doorEdge(ROOM, { a = "r", b = "s", x = 20, z = 5, width = 12 })).to.equal(nil)
		end)
	end)

	describe("wallSegments", function()
		it("builds four walls for a room without doors", function()
			expect(#OfficeLayoutUtils.wallSegments(ROOM, {})).to.equal(4)
		end)

		it("splits a wall around a door", function()
			local segments = OfficeLayoutUtils.wallSegments(ROOM, { { a = "r", b = "s", x = 10, z = 0, width = 4 } })
			expect(#segments).to.equal(5)
			expect(segments[1].x1).to.equal(0)
			expect(segments[1].x2).to.equal(8)
			expect(segments[1].z1).to.equal(0)
			expect(segments[2].x1).to.equal(12)
			expect(segments[2].x2).to.equal(20)
		end)

		it("ignores other rooms' doors", function()
			expect(#OfficeLayoutUtils.wallSegments(ROOM, { { a = "x", b = "y", x = 10, z = 0, width = 4 } })).to.equal(
				4
			)
		end)
	end)

	describe("mergedWallSegments", function()
		-- The merged spans on one wall line, as { from, to } pairs in order.
		local function spans(segments, horizontal, fixed)
			local found = {}
			for _, segment in segments do
				if horizontal and segment.z1 == segment.z2 and segment.z1 == fixed then
					table.insert(found, { segment.x1, segment.x2 })
				elseif not horizontal and segment.x1 == segment.x2 and segment.x1 == fixed then
					table.insert(found, { segment.z1, segment.z2 })
				end
			end
			table.sort(found, function(a, b)
				return a[1] < b[1]
			end)
			return found
		end

		local function twoRooms(second)
			return {
				startRoom = "a",
				rooms = {
					{ id = "a", name = "A", minX = 0, minZ = 0, maxX = 10, maxZ = 10 },
					second,
				},
				doors = {},
				markers = {},
				truck = TRUCK,
			}
		end

		it("emits a wall two rooms share once", function()
			local segments = OfficeLayoutUtils.mergedWallSegments(
				twoRooms({ id = "b", name = "B", minX = 10, minZ = 0, maxX = 20, maxZ = 10 })
			)
			expect(#spans(segments, false, 10)).to.equal(1)
			expect(#segments).to.equal(5)
		end)

		it("merges a partial overlap into one span", function()
			local segments = OfficeLayoutUtils.mergedWallSegments(
				twoRooms({ id = "b", name = "B", minX = 10, minZ = 5, maxX = 20, maxZ = 25 })
			)
			local line = spans(segments, false, 10)
			expect(#line).to.equal(1)
			expect(line[1][1]).to.equal(0)
			expect(line[1][2]).to.equal(25)
		end)

		it("merges touching collinear spans", function()
			local segments = OfficeLayoutUtils.mergedWallSegments(
				twoRooms({ id = "b", name = "B", minX = 10, minZ = 20, maxX = 20, maxZ = 30 })
			)
			local line = spans(segments, false, 10)
			expect(#line).to.equal(2)
			local touching = OfficeLayoutUtils.mergedWallSegments(
				twoRooms({ id = "b", name = "B", minX = 10, minZ = 10, maxX = 20, maxZ = 30 })
			)
			local joined = spans(touching, false, 10)
			expect(#joined).to.equal(1)
			expect(joined[1][2]).to.equal(30)
		end)

		it("keeps the real layout's door gaps", function()
			local segments = OfficeLayoutUtils.mergedWallSegments(LAYOUT)
			local line = spans(segments, true, 60)
			expect(#line).to.equal(4)
			expect(line[1][1]).to.equal(0)
			expect(line[1][2]).to.equal(12)
			expect(line[2][1]).to.equal(18)
			expect(line[2][2]).to.equal(47)
			expect(line[3][1]).to.equal(53)
			expect(line[3][2]).to.equal(77)
			expect(line[4][1]).to.equal(83)
			expect(line[4][2]).to.equal(100)
		end)

		it("merges the bay and open-plan wall at x = 40 around both doors", function()
			local line = spans(OfficeLayoutUtils.mergedWallSegments(LAYOUT), false, 40)
			expect(#line).to.equal(3)
			expect(line[1][2]).to.equal(11)
			expect(line[2][1]).to.equal(19)
			expect(line[2][2]).to.equal(41)
			expect(line[3][1]).to.equal(49)
		end)

		it("builds the real layout from 18 pieces totalling 692 studs", function()
			local segments = OfficeLayoutUtils.mergedWallSegments(LAYOUT)
			local total = 0
			for _, segment in segments do
				total += (segment.x2 - segment.x1) + (segment.z2 - segment.z1)
			end
			expect(#segments).to.equal(18)
			expect(total).to.equal(692)
		end)
	end)

	describe("lookups", function()
		it("finds rooms, markers and markers of a kind", function()
			expect(OfficeLayoutUtils.room(LAYOUT, "archive").name).to.equal("Archive")
			expect(OfficeLayoutUtils.marker(LAYOUT, "bay.spawn.1").room).to.equal("bay")
			expect(#OfficeLayoutUtils.markersOf(LAYOUT, "spawn")).to.equal(4)
			expect(OfficeLayoutUtils.room(LAYOUT, "attic")).to.equal(nil)
		end)
	end)

	describe("lightPoints", function()
		it("spreads lights evenly about one per spacing", function()
			local bay = OfficeLayoutUtils.room(LAYOUT, "bay")
			local points = OfficeLayoutUtils.lightPoints(bay, 15)
			expect(#points).to.equal(4)
			expect(points[1][1]).to.equal(10)
			expect(points[1][2]).to.equal(7.5)
			expect(points[4][1]).to.equal(30)
			expect(points[4][2]).to.equal(22.5)
		end)

		it("puts at least one light in the middle of a small room", function()
			local points = OfficeLayoutUtils.lightPoints(ROOM, 15)
			expect(#points).to.equal(1)
			expect(points[1][1]).to.equal(10)
			expect(points[1][2]).to.equal(5)
		end)
	end)

	describe("bounds", function()
		it("spans the room from the floor to the given height", function()
			local min, max = OfficeLayoutUtils.bounds(ROOM, 12)
			expect(min).to.equal(Vector3.new(0, 0, 0))
			expect(max).to.equal(Vector3.new(20, 12, 10))
		end)
	end)

	describe("route", function()
		it("lists Harlow's patrol points in walking order", function()
			expect(#LAYOUT.route).to.equal(7)
			expect(OfficeLayoutUtils.marker(LAYOUT, LAYOUT.route[1]).kind).to.equal("patrol")
			expect(OfficeLayoutUtils.marker(LAYOUT, LAYOUT.rest).room).to.equal("breakRoom")
		end)
	end)

	describe("roomAt", function()
		it("finds the room a point stands in, with its camera number", function()
			local room, index = OfficeLayoutUtils.roomAt(LAYOUT, 10, 10)
			expect(room.id).to.equal("bay")
			expect(index).to.equal(1)
			local archive, archiveIndex = OfficeLayoutUtils.roomAt(LAYOUT, 120, 20)
			expect(archive.name).to.equal("Archive")
			expect(archiveIndex).to.equal(7)
		end)

		it("returns nothing outside every room", function()
			local room, index = OfficeLayoutUtils.roomAt(LAYOUT, -50, -50)
			expect(room).to.equal(nil)
			expect(index).to.equal(nil)
		end)

		it("gives a shared wall to the first room listed", function()
			local room = OfficeLayoutUtils.roomAt(LAYOUT, 40, 10)
			expect(room.id).to.equal("bay")
		end)
	end)
end
