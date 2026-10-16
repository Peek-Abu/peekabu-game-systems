local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideSpotUtils = require(script.Parent.HideSpotUtils)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)

-- A desk 5 x 3 x 3 standing on the floor at y = 10, turned a quarter round; a 5 x 3.1 x 3 table unturned.
local DESK_SIZE = Vector3.new(5, 3, 3)
local DESK = CFrame.new(100, 10 + 1.5, 50) * CFrame.Angles(0, math.pi / 2, 0)
local TABLE_SIZE = Vector3.new(5, 3.1, 3)
local TABLE = CFrame.new(0, 1.55, 0)
-- A character's root stands 1.4 studs over its feet.
local STAND = 1.4
-- A tall supply cabinet 4.3 x 8 x 3.45 on the floor at y = 0.
local CABINET_SIZE = Vector3.new(4.3, 8, 3.45)
local CABINET = CFrame.new(20, 4, 20)

return function()
	describe("spotOf", function()
		it("hides under desks and tables, and inside the tall supply cabinet; never in a locker", function()
			expect(HideSpotUtils.spotOf("desk")).to.equal("under")
			expect(HideSpotUtils.spotOf("table")).to.equal("under")
			expect(HideSpotUtils.spotOf("cabinet")).to.equal("inside")
			expect(HideSpotUtils.spotOf("locker")).to.equal(nil)
			expect(HideSpotUtils.spotOf("shelf")).to.equal(nil)
		end)
	end)

	describe("spotFrame", function()
		it("keeps the furniture's front unless its back is clearly more open", function()
			expect(HideSpotUtils.spotFrame("table", TABLE, 10, 10)).to.equal(TABLE)
			expect(HideSpotUtils.spotFrame("table", TABLE, 2, 2 + HideConstants.OPEN_MARGIN)).to.equal(TABLE)
			-- A desk's knee-hole is always its front.
			expect(HideSpotUtils.spotFrame("desk", DESK, 2, 12)).to.equal(DESK)
			local turned = HideSpotUtils.spotFrame("table", TABLE, 2, 12)
			expect(turned.Position).to.equal(TABLE.Position)
			expect(turned.LookVector:Dot(TABLE.LookVector)).to.be.near(-1, 1e-6)
		end)
	end)

	describe("frames", function()
		it("stands the root at standing height under the desk, across the knee-hole away from the drawers", function()
			local frames = HideSpotUtils.frames("desk", DESK, DESK_SIZE, STAND)
			expect(frames.hide.Position.Y).to.be.near(10 + STAND, 1e-6)
			local inDesk = DESK:PointToObjectSpace(frames.hide.Position)
			expect(math.abs(inDesk.X) < DESK_SIZE.X / 2 and math.abs(inDesk.Z) < DESK_SIZE.Z / 2).to.equal(true)
			-- Head toward the front-left corner: forward has a -X (away from the +X pedestal) and a -Z part.
			local forward = DESK:VectorToObjectSpace(frames.hide.LookVector)
			expect(forward.X < -0.5 and forward.Z < -0.5).to.equal(true)
		end)

		it("lays the body along a table's length", function()
			local frames = HideSpotUtils.frames("table", TABLE, TABLE_SIZE, STAND)
			expect(frames.hide.LookVector:Dot(-TABLE.RightVector)).to.be.near(1, 1e-6)
		end)

		it("peeks low out from under the front edge", function()
			local frames = HideSpotUtils.frames("desk", DESK, DESK_SIZE, STAND)
			expect(frames.peek.Position.Y).to.be.near(10 + HideConstants.UNDER_EYE, 1e-6)
			expect(frames.peek.LookVector:Dot(DESK.LookVector)).to.be.near(1, 1e-6)
		end)

		it("stands the body upright inside a cabinet, facing its door", function()
			local frames = HideSpotUtils.frames("cabinet", CABINET, CABINET_SIZE, STAND)
			expect(frames.hide.Position.Y).to.be.near(STAND, 1e-6)
			local inside = CABINET:PointToObjectSpace(frames.hide.Position)
			expect(math.abs(inside.X) < 0.5 and math.abs(inside.Z) < CABINET_SIZE.Z / 2).to.equal(true)
			expect(frames.hide.LookVector:Dot(CABINET.LookVector)).to.be.near(1, 1e-6)
		end)

		it("peeks out through the cabinet door's louvres, at eye height", function()
			local frames = HideSpotUtils.frames("cabinet", CABINET, CABINET_SIZE, STAND)
			expect(frames.peek.Position.Y).to.be.near(HideConstants.INSIDE_EYE, 1e-6)
			expect(CABINET:PointToObjectSpace(frames.peek.Position).Z < -CABINET_SIZE.Z / 2).to.equal(true)
			expect(frames.peek.LookVector:Dot(CABINET.LookVector)).to.be.near(1, 1e-6)
		end)

		it("puts the prompt on the front face and tries the front exit first", function()
			local frames = HideSpotUtils.frames("table", TABLE, TABLE_SIZE, STAND)
			expect(frames.prompt.Z).to.be.near(-TABLE_SIZE.Z / 2 - 0.3, 1e-6)
			expect(#frames.exits).to.equal(4)
			local front = frames.exits[1].Position
			expect(front.Z).to.be.near(-(TABLE_SIZE.Z / 2 + HideConstants.EXIT_GAP), 1e-6)
			expect(front.Y).to.be.near(STAND, 1e-6)
			expect(frames.exits[2].Position.Z > 0).to.equal(true)
		end)
	end)
end
