local OfficeDoorUtils = require(script.Parent.OfficeDoorUtils)

local ORIGIN = CFrame.new(1000, 0, 500)
local DOOR = { a = "kit", b = "hall", x = 10, z = 0, width = 6, kind = "solid" }
local KIT = { id = "kit", name = "Kit", minX = 0, maxX = 20, minZ = 0, maxZ = 10, zone = "work" }
local HALL = { id = "hall", name = "Corridor", minX = 0, maxX = 20, minZ = -4, maxZ = 0, zone = "hallway" }

local function close(a, b)
	return math.abs(a - b) < 1e-3
end

return function()
	describe("leafFrame", function()
		it("fills the opening at fraction 0, centred at half the door height", function()
			local frame = OfficeDoorUtils.leafFrame(DOOR, "minZ", 1, 0, ORIGIN)
			expect(close(frame.X, 1010) and close(frame.Y, 4.5) and close(frame.Z, 500)).to.equal(true)
			expect(close(frame.LookVector.Z, -1)).to.equal(true)
		end)

		it("turns 95 degrees about the hinge at x = 7 toward +Z at fraction 1 (sign +1, minZ edge)", function()
			local frame = OfficeDoorUtils.leafFrame(DOOR, "minZ", 1, 1, ORIGIN)
			-- Centre is 3 studs from the hinge: (7 + 3 cos 95, 3 sin 95) = (6.7385, 2.9886).
			expect(close(frame.X, 1006.7385)).to.equal(true)
			expect(close(frame.Y, 4.5)).to.equal(true)
			expect(close(frame.Z, 502.9886)).to.equal(true)
			-- The leaf's width axis now points mostly along Z.
			expect(close(frame.RightVector.Z, math.sin(math.rad(95)))).to.equal(true)
		end)

		it("swings the other way for sign -1", function()
			local frame = OfficeDoorUtils.leafFrame(DOOR, "minZ", -1, 1, ORIGIN)
			expect(close(frame.Z, 497.0114)).to.equal(true)
		end)

		it("hinges a vertical door at z - width/2 and swings toward +X for sign +1", function()
			local door = { a = "kit", b = "hall", x = 0, z = 10, width = 6, kind = "solid" }
			local closed = OfficeDoorUtils.leafFrame(door, "minX", 1, 0, CFrame.identity)
			expect(close(closed.X, 0) and close(closed.Z, 10)).to.equal(true)
			local open = OfficeDoorUtils.leafFrame(door, "minX", 1, 1, CFrame.identity)
			-- Hinge (0, 7); centre 3 along +Z rotates to (3 sin 95, 7 + 3 cos 95) = (2.9886, 6.7385).
			expect(close(open.X, 2.9886)).to.equal(true)
			expect(close(open.Z, 6.7385)).to.equal(true)
		end)
	end)

	describe("swingSign", function()
		it("swings into the kit room, whichever side it is on", function()
			-- minZ edge of the kit room: into the kit is +Z.
			expect(OfficeDoorUtils.swingSign(DOOR, "minZ", KIT)).to.equal(1)
			-- The same door seen from the hallway (its maxZ edge): into the kit is +Z, so -1 from the hall's edge sign.
			local flipped = { a = "hall", b = "kit", x = 10, z = 0, width = 6, kind = "solid" }
			expect(OfficeDoorUtils.swingSign(flipped, "maxZ", HALL)).to.equal(1)
		end)

		it("swings away from a max edge into room A", function()
			expect(OfficeDoorUtils.swingSign(DOOR, "maxZ", KIT)).to.equal(-1)
			expect(OfficeDoorUtils.swingSign(DOOR, "maxX", KIT)).to.equal(-1)
			expect(OfficeDoorUtils.swingSign(DOOR, "minX", KIT)).to.equal(1)
		end)
	end)

	describe("facadeFrame", function()
		it("stands flush on the room side of the wall", function()
			local facade = { room = "kit", x = 10, z = 0, width = 6, kind = "entrance" }
			local frame = OfficeDoorUtils.facadeFrame(facade, KIT, CFrame.identity)
			expect(close(frame.Z, 0.65) and close(frame.Y, 4.5)).to.equal(true)
			local east = { room = "kit", x = 20, z = 5, width = 6, kind = "stairwell" }
			local eastFrame = OfficeDoorUtils.facadeFrame(east, KIT, CFrame.identity)
			expect(close(eastFrame.X, 19.35)).to.equal(true)
			expect(close(math.abs(eastFrame.RightVector.Z), 1)).to.equal(true)
		end)

		it("is nil off the walls", function()
			local facade = { room = "kit", x = 10, z = 5, width = 6, kind = "entrance" }
			expect(OfficeDoorUtils.facadeFrame(facade, KIT, CFrame.identity)).to.equal(nil)
		end)
	end)

	describe("near", function()
		it("returns only closed doors within the radius on the ground plane", function()
			local doors = {
				{ id = "a|b", position = Vector3.new(0, 4, 0), open = false },
				{ id = "c|d", position = Vector3.new(5, 4, 0), open = true },
				{ id = "e|f", position = Vector3.new(30, 4, 0), open = false },
				{ id = "g|h", position = Vector3.new(0, 90, 9), open = false },
			}
			local ids = OfficeDoorUtils.near(doors, Vector3.new(0, 0, 0), 10)
			expect(#ids).to.equal(2)
			expect(ids[1]).to.equal("a|b")
			expect(ids[2]).to.equal("g|h")
		end)
	end)

	describe("canClose", function()
		local min, max = Vector3.new(7, 0, -0.5), Vector3.new(13, 9, 0.5)
		it("is false with a body at the door centre", function()
			expect(OfficeDoorUtils.canClose(min, max, { Vector3.new(10, 3, 0) })).to.equal(false)
		end)
		it("is false just inside the 1 stud margin", function()
			expect(OfficeDoorUtils.canClose(min, max, { Vector3.new(10, 3, 1.4) })).to.equal(false)
		end)
		it("is true with a body 3 studs outside the box", function()
			expect(OfficeDoorUtils.canClose(min, max, { Vector3.new(10, 3, 3.5) })).to.equal(true)
		end)
		it("is true with nobody about", function()
			expect(OfficeDoorUtils.canClose(min, max, {})).to.equal(true)
		end)
	end)
end
