local OfficeDoorUtils = require(script.Parent.OfficeDoorUtils)
local OfficeConstants = require(script.Parent.Parent.Data.OfficeConstants)

local ORIGIN = CFrame.new(1000, 0, 500)
local DOOR = { a = "kit", b = "hall", x = 10, z = 0, width = 6, kind = "solid" }
local KIT = { id = "kit", name = "Kit", minX = 0, maxX = 20, minZ = 0, maxZ = 10, zone = "work" }
local HALL = { id = "hall", name = "Corridor", minX = 0, maxX = 20, minZ = -4, maxZ = 0, zone = "hallway" }

local function close(a, b)
	return math.abs(a - b) < 1e-3
end

-- A leaf is the clear opening: the door minus a casing each side, DOOR_HEIGHT less one casing tall.
local CASING = OfficeConstants.SHELL.casing
local LEAF_WIDTH = DOOR.width - 2 * CASING
local LEAF_MID = (OfficeConstants.DOOR_HEIGHT - CASING) / 2
local HINGE_OFFSET = LEAF_WIDTH / 2

return function()
	describe("leafSize", function()
		it("fills the clear opening: the door minus a casing each side, one casing short of DOOR_HEIGHT", function()
			local size = OfficeDoorUtils.leafSize({ a = "kit", b = "hall", x = 10, z = 0, width = 6.8, kind = "solid" })
			expect(close(size.X, 6.1)).to.equal(true)
			expect(close(size.Y, OfficeConstants.DOOR_HEIGHT - 0.35)).to.equal(true)
			expect(close(size.Z, OfficeConstants.DOOR_LEAF_THICKNESS)).to.equal(true)
		end)
	end)

	describe("leafFrame", function()
		it("fills the opening at fraction 0, centred at half the leaf height", function()
			local frame = OfficeDoorUtils.leafFrame(DOOR, "minZ", 1, 0, ORIGIN)
			expect(close(frame.X, 1010) and close(frame.Y, LEAF_MID) and close(frame.Z, 500)).to.equal(true)
			expect(close(frame.LookVector.Z, 1)).to.equal(true)
		end)

		it("turns 95 degrees about the leaf's hinge edge toward +Z at fraction 1 (sign +1, minZ edge)", function()
			local frame = OfficeDoorUtils.leafFrame(DOOR, "minZ", 1, 1, ORIGIN)
			-- The hinge is half a leaf width left of the centre; the centre swings round it.
			local angle = math.rad(95)
			expect(close(frame.X, 1010 - HINGE_OFFSET + HINGE_OFFSET * math.cos(angle))).to.equal(true)
			expect(close(frame.Y, LEAF_MID)).to.equal(true)
			expect(close(frame.Z, 500 + HINGE_OFFSET * math.sin(angle))).to.equal(true)
			-- The leaf's width axis now points mostly along Z (its local +X, the hinge side, toward -Z).
			expect(close(frame.RightVector.Z, -math.sin(angle))).to.equal(true)
		end)

		it("swings the other way for sign -1", function()
			local frame = OfficeDoorUtils.leafFrame(DOOR, "minZ", -1, 1, ORIGIN)
			expect(close(frame.Z, 500 - HINGE_OFFSET * math.sin(math.rad(95)))).to.equal(true)
		end)

		it("hinges a vertical door at its leaf's -z edge and swings toward +X for sign +1", function()
			local door = { a = "kit", b = "hall", x = 0, z = 10, width = 6, kind = "solid" }
			local closed = OfficeDoorUtils.leafFrame(door, "minX", 1, 0, CFrame.identity)
			expect(close(closed.X, 0) and close(closed.Z, 10)).to.equal(true)
			local open = OfficeDoorUtils.leafFrame(door, "minX", 1, 1, CFrame.identity)
			local angle = math.rad(95)
			local hingeZ = 10 - HINGE_OFFSET
			expect(close(open.X, HINGE_OFFSET * math.sin(angle))).to.equal(true)
			expect(close(open.Z, hingeZ + HINGE_OFFSET * math.cos(angle))).to.equal(true)
		end)
	end)

	describe("hinge side", function()
		it("keeps the hinge at the leaf's local +X for horizontal and vertical doors, closed and open", function()
			local horizontal = DOOR
			local vertical = { a = "kit", b = "hall", x = 0, z = 10, width = 6, kind = "solid" }
			for fraction = 0, 1 do
				local h = OfficeDoorUtils.leafFrame(horizontal, "minZ", 1, fraction, ORIGIN)
				local hinge = h * Vector3.new(LEAF_WIDTH / 2, 0, 0)
				expect(close(hinge.X, 1010 - HINGE_OFFSET) and close(hinge.Z, 500)).to.equal(true)
				local v = OfficeDoorUtils.leafFrame(vertical, "minX", 1, fraction, ORIGIN)
				local vhinge = v * Vector3.new(LEAF_WIDTH / 2, 0, 0)
				expect(close(vhinge.X, 1000) and close(vhinge.Z, 510 - HINGE_OFFSET)).to.equal(true)
			end
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
			expect(close(frame.Z, 0.65) and close(frame.Y, OfficeConstants.DOOR_HEIGHT / 2)).to.equal(true)
			local east = { room = "kit", x = 20, z = 5, width = 6, kind = "stairwell" }
			local eastFrame = OfficeDoorUtils.facadeFrame(east, KIT, CFrame.identity)
			expect(close(eastFrame.X, 19.35)).to.equal(true)
			expect(close(math.abs(eastFrame.RightVector.Z), 1)).to.equal(true)
			-- The same hinge convention as a door: local +X toward -Z on an X wall, toward -X on a Z wall.
			expect(close(eastFrame.RightVector.Z, -1)).to.equal(true)
			expect(close(frame.RightVector.X, -1)).to.equal(true)
		end)

		it("is nil off the walls", function()
			local facade = { room = "kit", x = 10, z = 5, width = 6, kind = "entrance" }
			expect(OfficeDoorUtils.facadeFrame(facade, KIT, CFrame.identity)).to.equal(nil)
		end)
	end)

	describe("facadeLeaves", function()
		it("fits an entrance's two leaves inside the casing, side by side", function()
			local casing = OfficeConstants.SHELL.casing
			local leaves = OfficeDoorUtils.facadeLeaves({ room = "kit", x = 10, z = 0, width = 6, kind = "entrance" })
			expect(#leaves).to.equal(2)
			local lo, hi = math.huge, -math.huge
			for _, leaf in leaves do
				expect(close(leaf.size.Y, OfficeConstants.DOOR_HEIGHT - casing)).to.equal(true)
				lo = math.min(lo, leaf.offset.X - leaf.size.X / 2)
				hi = math.max(hi, leaf.offset.X + leaf.size.X / 2)
				-- Stands on the floor: the frame is DOOR_HEIGHT / 2 up.
				expect(close(OfficeConstants.DOOR_HEIGHT / 2 + leaf.offset.Y - leaf.size.Y / 2, 0)).to.equal(true)
			end
			expect(close(lo, -(3 - casing))).to.equal(true)
			expect(close(hi, 3 - casing)).to.equal(true)
			expect(close(leaves[1].offset.X + leaves[1].size.X / 2, 0)).to.equal(true)
		end)

		it("gives a stairwell one solid leaf inside the casing", function()
			local leaves = OfficeDoorUtils.facadeLeaves({ room = "kit", x = 10, z = 0, width = 6, kind = "stairwell" })
			expect(#leaves).to.equal(1)
			expect(close(leaves[1].size.X, 6 - 2 * OfficeConstants.SHELL.casing)).to.equal(true)
			expect(leaves[1].side).to.equal(0)
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
		it("is false for a body mid-jump, 8 studs above the floor", function()
			expect(OfficeDoorUtils.canClose(min, max, { Vector3.new(10, 8, 0) })).to.equal(false)
		end)
		it("is true with a body 3 studs outside the box", function()
			expect(OfficeDoorUtils.canClose(min, max, { Vector3.new(10, 3, 3.5) })).to.equal(true)
		end)
		it("is true with nobody about", function()
			expect(OfficeDoorUtils.canClose(min, max, {})).to.equal(true)
		end)
	end)

	describe("npcNear", function()
		local centre = Vector3.new(10, 4.5, 0)
		it("is true with an NPC root within the radius on the ground plane", function()
			expect(OfficeDoorUtils.npcNear({ Vector3.new(16, 3, 8) }, centre, 10)).to.equal(true)
		end)
		it("ignores height", function()
			expect(OfficeDoorUtils.npcNear({ Vector3.new(10, 40, 0) }, centre, 10)).to.equal(true)
		end)
		it("is false beyond the radius, or with no NPC", function()
			expect(OfficeDoorUtils.npcNear({ Vector3.new(17, 3, 8) }, centre, 10)).to.equal(false)
			expect(OfficeDoorUtils.npcNear({}, centre, 10)).to.equal(false)
		end)
	end)

	describe("ahead", function()
		local point = Vector3.new(0, 3, 0)
		it("is true for a door in front of the heading", function()
			expect(OfficeDoorUtils.ahead(Vector3.new(2, 4.5, 6), point, Vector3.new(0, 0, 1))).to.equal(true)
		end)
		it("is false for a door beside or behind him", function()
			expect(OfficeDoorUtils.ahead(Vector3.new(6, 4.5, 0), point, Vector3.new(0, 0, 1))).to.equal(false)
			expect(OfficeDoorUtils.ahead(Vector3.new(1, 4.5, -5), point, Vector3.new(0, 0, 1))).to.equal(false)
		end)
		it("ignores the heading's height", function()
			expect(OfficeDoorUtils.ahead(Vector3.new(0, 4.5, 6), point, Vector3.new(0, -5, 1))).to.equal(true)
		end)
		it("treats every door as ahead with no heading, or a vertical one", function()
			expect(OfficeDoorUtils.ahead(Vector3.new(0, 4.5, -6), point, nil)).to.equal(true)
			expect(OfficeDoorUtils.ahead(Vector3.new(0, 4.5, -6), point, Vector3.new(0, 1, 0))).to.equal(true)
		end)
	end)
end
