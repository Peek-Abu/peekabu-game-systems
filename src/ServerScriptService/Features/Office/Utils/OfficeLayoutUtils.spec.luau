local ServerScriptService = game:GetService("ServerScriptService")

local OfficeLayoutUtils = require(script.Parent.OfficeLayoutUtils)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)

local LAYOUT = OfficeLayoutConstants.LAYOUT
local ROOM = { id = "r", name = "R", minX = 0, minZ = 0, maxX = 20, maxZ = 10 }
local TRUCK = { minX = 0, minZ = 0, maxX = 1, maxZ = 1, clockX = 0, clockZ = 0 }

return function()
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
end
