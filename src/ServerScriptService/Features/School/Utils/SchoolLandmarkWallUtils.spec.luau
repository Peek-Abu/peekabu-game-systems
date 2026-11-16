local Walls = require(script.Parent.SchoolLandmarkWallUtils)

return function()
	describe("wall pieces in a landmark", function()
		it("snaps a piece near a kit wall out to the room's wall, and leaves the middle alone", function()
			local kit = { minX = 10, maxX = 74, minZ = 0, maxZ = 56 }
			local room = { minX = 9, maxX = 75, minZ = 0, maxZ = 67 }
			local markers = {
				{ id = "a", room = "r", kind = "prop", art = "scoreboard", x = 42, z = 55.08, rotation = 0 },
				{
					id = "b",
					room = "r",
					kind = "prop",
					art = "schoolVending",
					x = 71.32,
					z = 32,
					rotation = math.pi / 2,
				},
				{ id = "c", room = "r", kind = "pile", x = 40, z = 30 },
			}
			Walls.snapToWalls(markers, kit, room)
			expect(markers[1].z).to.be.near(66.08, 1e-6)
			expect(markers[2].x).to.be.near(72.32, 1e-6)
			expect(markers[3].x).to.equal(40)
			expect(markers[3].z).to.equal(30)
		end)

		it("holds a wall's floor pieces when asked, but still hangs its wall props on the real wall", function()
			local kit = { minX = 10, maxX = 74, minZ = 0, maxZ = 56 }
			local room = { minX = 9, maxX = 75, minZ = 0, maxZ = 67 }
			local markers = {
				{ id = "a", room = "r", kind = "prop", art = "scoreboard", x = 42, z = 55.08, rotation = 0 },
				{ id = "b", room = "r", kind = "counter", art = "servingCounter", x = 42, z = 53.4, rotation = 0 },
			}
			Walls.snapToWalls(markers, kit, room, "maxZ")
			expect(markers[1].z).to.be.near(66.08, 1e-6)
			expect(markers[2].z).to.equal(53.4)
		end)

		it("puts a back door only where no wall piece stands", function()
			local room = { minX = 0, maxX = 40, minZ = 0, maxZ = 20 }
			local markers = { { id = "a", room = "r", kind = "prop", art = "bench", x = 20, z = 18.5, rotation = 0 } }
			local x = Walls.freeDoorX(markers, room, 20, 10, 8, 20)
			expect(x ~= nil).to.equal(true)
			expect(math.abs(x - 20) >= 3.8 + 5 + 1 - 1e-6).to.equal(true)
			expect(
				Walls.freeDoorX(
					{ { id = "w", room = "r", kind = "prop", art = "bleachers", x = 20, z = 12, rotation = 0 } },
					{ minX = 0, maxX = 20, minZ = 0, maxZ = 20 },
					20,
					10,
					8,
					10
				)
			).to.equal(nil)
		end)
	end)
end
