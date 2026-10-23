local OfficeKitUtils = require(script.Parent.OfficeKitUtils)
local OfficeLayoutUtils = require(script.Parent.OfficeLayoutUtils)

local function fixture(deskRotation)
	return {
		id = "fixture",
		roomType = "pods",
		name = "Fixture",
		size = "M",
		width = 20,
		depth = 10,
		door = { offset = 5, width = 6, kind = "solid" },
		glass = { from = 12, to = 18 },
		markers = {
			{ kind = "desk", x = 2, z = 3, rotation = deskRotation },
			{ kind = "pile", x = 4, z = 8 },
		},
	}
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

return function()
	it("facing minZ is the identity", function()
		local p = OfficeKitUtils.place(fixture(0), "r1", 100, 50, "minZ", false)
		expect(p.room.minX).to.equal(100)
		expect(p.room.maxX).to.equal(120)
		expect(p.room.minZ).to.equal(50)
		expect(p.room.maxZ).to.equal(60)
		expect(p.doorX).to.equal(105)
		expect(p.doorZ).to.equal(50)
		expect(p.doorWidth).to.equal(6)
		expect(p.doorKind).to.equal("solid")
		local desk = p.markers[1]
		expect(desk.id).to.equal("r1.desk.1")
		expect(desk.x).to.equal(102)
		expect(desk.z).to.equal(53)
		expect(desk.rotation).to.equal(0)
		expect(p.markers[2].id).to.equal("r1.pile.1")
		expect(p.pane.x1).to.equal(112)
		expect(p.pane.z1).to.equal(50)
		expect(p.pane.x2).to.equal(118)
		expect(p.pane.z2).to.equal(50)
	end)

	it("mirroring flips x and negates yaw", function()
		local p = OfficeKitUtils.place(fixture(0.5), "r1", 100, 50, "minZ", true)
		expect(p.markers[1].x).to.equal(118)
		expect(p.markers[1].z).to.equal(53)
		expect(near(p.markers[1].rotation, -0.5)).to.equal(true)
		expect(p.doorX).to.equal(115)
		expect(p.pane.x1).to.equal(102)
		expect(p.pane.x2).to.equal(108)
	end)

	it("every facing keeps the door on the front edge and every marker inside", function()
		for _, facing in { "minZ", "maxZ", "minX", "maxX" } do
			for _, mirrored in { false, true } do
				local p = OfficeKitUtils.place(fixture(0), "r1", 100, 50, facing, mirrored)
				local door = { a = "r1", b = "x", x = p.doorX, z = p.doorZ, width = 6 }
				expect(OfficeLayoutUtils.doorEdge(p.room, door)).to.equal(facing)
				for _, m in p.markers do
					expect(m.x >= p.room.minX and m.x <= p.room.maxX).to.equal(true)
					expect(m.z >= p.room.minZ and m.z <= p.room.maxZ).to.equal(true)
				end
				local area = (p.room.maxX - p.room.minX) * (p.room.maxZ - p.room.minZ)
				expect(near(area, 200)).to.equal(true)
			end
		end
	end)

	it("facing minX turns local +Z into world +X", function()
		local p = OfficeKitUtils.place(fixture(0), "r1", 0, 0, "minX", false)
		expect(p.markers[2].x).to.equal(8)
	end)

	it("rooms carry floor 1 and their kit", function()
		local p = OfficeKitUtils.place(fixture(0), "r1", 0, 0, "minZ", false)
		expect(p.room.floor).to.equal(1)
		expect(p.room.kit).to.equal("fixture")
		expect(p.room.roomType).to.equal("pods")
		expect(p.room.zone).to.equal("pods")
		expect(p.room.name).to.equal("Fixture")
	end)

	it("copies a marker's art key and leaves other markers without one", function()
		local kit = fixture(0)
		table.insert(kit.markers, { kind = "prop", x = 10, z = 5, art = "sofa" })
		local p = OfficeKitUtils.place(kit, "r1", 100, 50, "minZ", false)
		expect(p.markers[3].kind).to.equal("prop")
		expect(p.markers[3].id).to.equal("r1.prop.1")
		expect(p.markers[3].art).to.equal("sofa")
		expect(p.markers[1].art).to.equal(nil)
	end)
end
