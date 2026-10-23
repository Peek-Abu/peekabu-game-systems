local Utils = require(script.Parent.OfficeFurniturePlacementUtils)
return function()
	local function layout(markers, doors)
		return {
			startRoom = "room",
			rooms = { { id = "room", name = "Room", minX = 0, maxX = 24, minZ = 0, maxZ = 24 } },
			markers = markers,
			doors = doors or {},
			truck = { minX = 0, maxX = 1, minZ = 0, maxZ = 1, clockX = 0, clockZ = 0 },
			route = {},
			rest = "",
		}
	end
	it("clones authored markers and faces every wall inward with a flush back", function()
		for _, case in
			{
				{ x = 1, z = 12, yaw = -math.pi / 2 },
				{ x = 23, z = 12, yaw = math.pi / 2 },
				{ x = 12, z = 1, yaw = math.pi },
				{ x = 12, z = 23, yaw = 0 },
			}
		do
			local marker = { id = "locker", kind = "locker", room = "room", x = case.x, z = case.z }
			local source = layout({ marker })
			local result = Utils.normalize(source)
			local placed = result.markers[1]
			expect(placed ~= marker).to.equal(true)
			expect(marker.rotation).to.equal(nil)
			expect(placed.rotation).to.equal(case.yaw)
			local back = Vector3.new(placed.x, 0, placed.z) + CFrame.Angles(0, placed.rotation, 0).ZVector * 1.25
			local distance = math.min(back.X, 24 - back.X, back.Z, 24 - back.Z)
			expect(math.abs(distance - 0.6) < 0.001).to.equal(true)
		end
	end)
	it("preserves explicit procedural rotations and coordinates exactly", function()
		local source = layout({ { id = "shelf", kind = "shelf", room = "room", x = 4, z = 6, rotation = math.pi / 2 } })
		local result = Utils.normalize(source).markers[1]
		expect(result.x).to.equal(4)
		expect(result.z).to.equal(6)
		expect(result.rotation).to.equal(math.pi / 2)
	end)
	it("mounts a board beside an opening without covering its approach", function()
		local source = layout(
			{ { id = "board", kind = "board", room = "room", x = 12, z = 1 } },
			{ { a = "room", b = "outside", x = 12, z = 0, width = 6 } }
		)
		local result = Utils.normalize(source).markers[1]
		expect(result.rotation).to.equal(math.pi)
		expect(math.abs(result.x - 12) >= 6.9).to.equal(true)
		expect(result.z < 1).to.equal(true)
	end)
	it("stands a board clear of low floor furniture too, now that it stands on the floor", function()
		-- A 3-high counter against the front wall where the board asks to go; a wall-hung board used to clear it.
		local source = layout({
			{ id = "board", kind = "board", room = "room", x = 12, z = 1 },
			{ id = "counter", kind = "counter", room = "room", x = 12, z = 1.75, rotation = math.pi },
		})
		local result = Utils.normalize(source).markers[1]
		expect(result.rotation).to.equal(math.pi)
		expect(math.abs(result.x - 12) >= 5.7 - 1e-6).to.equal(true)
	end)
	it("moves floor dressing plants into a corner without moving gameplay markers", function()
		local source = layout({
			{ id = "plant", kind = "plant", room = "room", x = 12, z = 12 },
			{ id = "item", kind = "item", room = "room", x = 8, z = 8 },
		})
		local result = Utils.normalize(source)
		expect(result.markers[1].x <= 2 or result.markers[1].x >= 22).to.equal(true)
		expect(result.markers[1].z <= 2 or result.markers[1].z >= 22).to.equal(true)
		expect(result.markers[2].x).to.equal(8)
		expect(result.markers[2].z).to.equal(8)
	end)
	it("refuses a wall fixture when all wall spans are too small instead of leaving it on the floor", function()
		local source = layout({ { id = "shelf", kind = "shelf", room = "room", x = 12, z = 12 } }, {
			{ a = "room", b = "a", x = 12, z = 0, width = 22 },
			{ a = "room", b = "b", x = 12, z = 24, width = 22 },
			{ a = "room", b = "c", x = 0, z = 12, width = 22 },
			{ a = "room", b = "d", x = 24, z = 12, width = 22 },
		})
		expect(function()
			Utils.normalize(source)
		end).to.throw()
	end)
	it("keeps relocated solids clear of cargo and patrol markers", function()
		local source = layout({
			{ id = "locker", kind = "locker", room = "room", x = 1, z = 12 },
			{ id = "item", kind = "item", room = "room", x = 1.85, z = 12 },
			{ id = "patrol", kind = "patrol", room = "room", x = 1.85, z = 16 },
		})
		local result = Utils.normalize(source)
		local solid = result.markers[1]
		for index = 2, 3 do
			local other = result.markers[index]
			expect(math.abs(solid.x - other.x) > 3 or math.abs(solid.z - other.z) > 3).to.equal(true)
		end
		expect(result.markers[2].z).to.equal(12)
		expect(result.markers[3].z).to.equal(16)
	end)
end
