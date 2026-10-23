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

	describe("elevatorFrame", function()
		local function facing(facade)
			return OfficeDoorUtils.elevatorFrame(facade, KIT, CFrame.identity)
		end

		it("stands on the room side of the wall at the elevator's height, +Z facing into the room", function()
			local inset = OfficeConstants.WALL_THICKNESS / 2 + OfficeConstants.ELEVATOR_FRONT_SIZE.Z / 2
			local minZ = facing({ room = "kit", x = 10, z = 0, width = 6, kind = "elevator" })
			expect(close(minZ.Z, inset) and close(minZ.X, 10)).to.equal(true)
			expect(close(minZ.LookVector.Z, -1)).to.equal(true)
			local maxZ = facing({ room = "kit", x = 10, z = 10, width = 6, kind = "elevator" })
			expect(close(maxZ.Z, 10 - inset)).to.equal(true)
			expect(close(maxZ.LookVector.Z, 1)).to.equal(true)
			local minX = facing({ room = "kit", x = 0, z = 5, width = 6, kind = "elevator" })
			expect(close(minX.X, inset) and close(minX.LookVector.X, -1)).to.equal(true)
			local maxX = facing({ room = "kit", x = 20, z = 5, width = 6, kind = "elevator" })
			expect(close(maxX.X, 20 - inset) and close(maxX.LookVector.X, 1)).to.equal(true)
			expect(close(minZ.Y, 4)).to.equal(true)
		end)

		it("is nil off the walls", function()
			expect(facing({ room = "kit", x = 10, z = 5, width = 6, kind = "elevator" })).to.equal(nil)
		end)
	end)

	describe("elevatorFrameFor", function()
		local function same(a, b)
			return (a.Position - b.Position).Magnitude < 1e-3 and (a.LookVector - b.LookVector).Magnitude < 1e-3
		end

		it(
			"keeps ELEVATOR_POINT, +Z facing world +X, in a layout with no elevator facade (the authored boot layout)",
			function()
				local point = require(
					game:GetService("ReplicatedStorage").Shared.Features.Office.Data.OfficeDecorConstants
				).ELEVATOR_POINT
				local boot = ORIGIN * CFrame.new(point) * CFrame.Angles(0, math.pi / 2, 0)
				expect(same(OfficeDoorUtils.elevatorFrameFor({ rooms = { KIT }, doors = {} }, ORIGIN), boot)).to.equal(
					true
				)
				local stairOnly = {
					rooms = { KIT },
					doors = {},
					facades = { { room = "kit", x = 10, z = 10, width = 6, kind = "stairwell" } },
				}
				local frame = OfficeDoorUtils.elevatorFrameFor(stairOnly, ORIGIN)
				expect(same(frame, boot)).to.equal(true)
				expect(close((frame * CFrame.new(0, 0, 1)).Position.X - frame.Position.X, 1)).to.equal(true)
			end
		)

		it("stands on the layout's first elevator facade", function()
			local first = { room = "kit", x = 10, z = 10, width = 6, kind = "elevator" }
			local layout = {
				rooms = { KIT },
				doors = {},
				facades = {
					{ room = "kit", x = 0, z = 5, width = 6, kind = "stairwell" },
					first,
					{ room = "kit", x = 20, z = 5, width = 6, kind = "elevator" },
				},
			}
			local expected = OfficeDoorUtils.elevatorFrame(first, KIT, ORIGIN)
			expect(same(OfficeDoorUtils.elevatorFrameFor(layout, ORIGIN), expected)).to.equal(true)
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

	describe("reach", function()
		local point = Vector3.new(0, 3, 0)
		local heading = Vector3.new(0, 0, 1)
		-- A closed 6-wide door at (x, 4.7, z): his line's band is width / 2 + 1 = 4 studs either side.
		local function door(x, z, open)
			return { id = "a|b", position = Vector3.new(x, 4.7, z), width = 6, open = open == true }
		end
		local function ids(doors)
			return OfficeDoorUtils.reach(doors, point, heading, 8)
		end
		it("includes a closed door 6 studs ahead on his line", function()
			local found = ids({ door(0, 6) })
			expect(#found).to.equal(1)
			expect(found[1]).to.equal("a|b")
		end)
		it("includes a door 6 ahead and 2 off his line: inside the band", function()
			expect(#ids({ door(2, 6) })).to.equal(1)
			expect(#ids({ door(0.5, 6) })).to.equal(1)
		end)
		it("skips a side door along a corridor: 5 to the side and 3 ahead, or 7 to the side and 2 ahead", function()
			expect(#ids({ door(5, 3) })).to.equal(0)
			expect(#ids({ door(-5, 3) })).to.equal(0)
			expect(#ids({ door(7, 2) })).to.equal(0)
		end)
		it("widens the band with the door: a 12-wide door 6 off his line is on it", function()
			local wide = { id = "a|b", position = Vector3.new(6, 4.7, 4), width = 12, open = false }
			expect(#ids({ wide })).to.equal(1)
		end)
		it("skips a door 9 studs ahead: beyond the reach", function()
			expect(#ids({ door(0, 9) })).to.equal(0)
		end)
		it("skips a door 6 studs behind him, and one level beside him", function()
			expect(#ids({ door(0, -6) })).to.equal(0)
			expect(#ids({ door(0.5, 0) })).to.equal(0)
			expect(#ids({ door(6, 0) })).to.equal(0)
		end)
		it("skips a door that is already open, and ignores height and the heading's height", function()
			expect(#ids({ door(0, 6, true) })).to.equal(0)
			local high = { id = "a|b", position = Vector3.new(0, 90, 6), width = 6, open = false }
			expect(#ids({ high })).to.equal(1)
			expect(#OfficeDoorUtils.reach({ door(0, 6) }, point, Vector3.new(0, -5, 1), 8)).to.equal(1)
		end)
		it("follows any heading, not only the axes", function()
			local diagonal = Vector3.new(1, 0, 1).Unit
			expect(#OfficeDoorUtils.reach({ door(4, 4) }, point, diagonal, 8)).to.equal(1)
			expect(#OfficeDoorUtils.reach({ door(6, 0) }, point, diagonal, 8)).to.equal(0)
		end)
		it("opens nothing with no heading, or a vertical one: nothing lies ahead of a man standing still", function()
			expect(#OfficeDoorUtils.reach({ door(0, 6), door(0, -6) }, point, nil, 8)).to.equal(0)
			expect(#OfficeDoorUtils.reach({ door(0, 6) }, point, Vector3.new(0, 1, 0), 8)).to.equal(0)
		end)
	end)

	describe("near", function()
		local point = Vector3.new(0, 3, 0)
		local function door(x, z, open)
			return { id = "a|b", position = Vector3.new(x, 4.7, z), width = 6, open = open == true }
		end
		it("includes a closed door 2.5 studs to his side: he is at the doorway, whatever his heading", function()
			expect(#OfficeDoorUtils.near({ door(2.5, 0) }, point, 3)).to.equal(1)
			expect(#OfficeDoorUtils.near({ door(0, -2.5) }, point, 3)).to.equal(1)
		end)
		it("skips a door 4 studs to the side, an open one, and ignores height", function()
			expect(#OfficeDoorUtils.near({ door(4, 0) }, point, 3)).to.equal(0)
			expect(#OfficeDoorUtils.near({ door(2.5, 0, true) }, point, 3)).to.equal(0)
			local high = { id = "a|b", position = Vector3.new(2.5, 90, 0), width = 6, open = false }
			expect(#OfficeDoorUtils.near({ high }, point, 3)).to.equal(1)
		end)
	end)

	describe("rattle", function()
		it("is the identity at both ends of the rattle", function()
			expect(OfficeDoorUtils.rattle(0)).to.equal(CFrame.identity)
			expect(OfficeDoorUtils.rattle(1)).to.equal(CFrame.identity)
			expect(OfficeDoorUtils.rattle(1.5)).to.equal(CFrame.identity)
		end)
		it("only turns about the vertical axis, never past the amplitude, and moves in between", function()
			local moved = false
			for step = 1, 99 do
				local frame = OfficeDoorUtils.rattle(step / 100)
				expect(frame.Position.Magnitude < 1e-6).to.equal(true)
				local _, yaw = frame:ToEulerAnglesYXZ()
				expect(math.abs(yaw) <= OfficeConstants.DOOR_RATTLE_ANGLE + 1e-6).to.equal(true)
				moved = moved or math.abs(yaw) > 1e-3
			end
			expect(moved).to.equal(true)
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
end
