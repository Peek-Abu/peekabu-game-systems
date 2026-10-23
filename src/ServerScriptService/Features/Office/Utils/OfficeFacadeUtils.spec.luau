local OfficeFacadeUtils = require(script.Parent.OfficeFacadeUtils)

-- A 10 x 10 junction with a door on its minX wall and a room against its maxX wall: only its minZ and maxZ walls are
-- free, with nothing outside them.
local JUNCTION = { id = "j", name = "Corridor", minX = 0, maxX = 10, minZ = 0, maxZ = 10, zone = "hallway" }
local WEST = { id = "w", name = "Corridor", minX = -10, maxX = 0, minZ = 2, maxZ = 8, zone = "hallway" }
local EAST = { id = "e", name = "Pods", minX = 10, maxX = 30, minZ = -5, maxZ = 15, zone = "work" }

local function layout(markers)
	return {
		rooms = { JUNCTION, WEST, EAST },
		doors = { { a = "j", b = "w", x = 0, z = 5, width = 6, kind = "open" } },
		markers = markers or {},
	}
end

return function()
	describe("candidates", function()
		it(
			"offers every free junction wall whose outside is clear, in the fixed wall order, as a 6-wide facade",
			function()
				local found = OfficeFacadeUtils.candidates(layout(), { JUNCTION }, {}, "stairwell")
				expect(#found).to.equal(2)
				expect(found[1].z).to.equal(0)
				expect(found[1].x).to.equal(5)
				expect(found[2].z).to.equal(10)
				for _, facade in found do
					expect(facade.room).to.equal("j")
					expect(facade.width).to.equal(6)
					expect(facade.kind).to.equal("stairwell")
				end
			end
		)

		it("skips a wall that already holds a facade, and names the kind asked for", function()
			local stairwell = { room = "j", x = 5, z = 0, width = 6, kind = "stairwell" }
			local found = OfficeFacadeUtils.candidates(layout(), { JUNCTION }, { stairwell }, "elevator")
			expect(#found).to.equal(1)
			expect(found[1].z).to.equal(10)
			expect(found[1].kind).to.equal("elevator")
		end)

		it("offers nothing in a dead end with a closet", function()
			local closet = { id = "j.closet.1", room = "j", kind = "closet", x = 5, z = 8, rotation = 0 }
			expect(#OfficeFacadeUtils.candidates(layout({ closet }), { JUNCTION }, {}, "stairwell")).to.equal(0)
		end)

		it("offers nothing when no junction is given", function()
			expect(#OfficeFacadeUtils.candidates(layout(), {}, {}, "stairwell")).to.equal(0)
		end)
	end)
end
