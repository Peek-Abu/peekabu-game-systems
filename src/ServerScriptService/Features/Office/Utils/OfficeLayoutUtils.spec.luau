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

	describe("lookups", function()
		it("finds rooms, markers and markers of a kind", function()
			expect(OfficeLayoutUtils.room(LAYOUT, "archive").name).to.equal("Archive")
			expect(OfficeLayoutUtils.marker(LAYOUT, "bay.spawn.1").room).to.equal("bay")
			expect(#OfficeLayoutUtils.markersOf(LAYOUT, "spawn")).to.equal(4)
			expect(OfficeLayoutUtils.room(LAYOUT, "attic")).to.equal(nil)
		end)
	end)
end
