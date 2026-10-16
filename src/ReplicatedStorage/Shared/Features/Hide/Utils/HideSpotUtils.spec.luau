local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideSpotUtils = require(script.Parent.HideSpotUtils)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)

-- A desk 5 x 3 x 3 standing on the floor at y = 10, turned a quarter round; a 2.5 x 7 x 2.5 locker unturned.
local DESK_SIZE = Vector3.new(5, 3, 3)
local DESK = CFrame.new(100, 10 + 1.5, 50) * CFrame.Angles(0, math.pi / 2, 0)
local LOCKER_SIZE = Vector3.new(2.5, 7, 2.5)
local LOCKER = CFrame.new(0, 3.5, 0)
-- A character's root stands 3 studs over its feet.
local STAND = 3

return function()
	describe("spotOf", function()
		it("hides under desks and tables, inside lockers and cabinets, and nowhere else", function()
			expect(HideSpotUtils.spotOf("desk")).to.equal("under")
			expect(HideSpotUtils.spotOf("table")).to.equal("under")
			expect(HideSpotUtils.spotOf("locker")).to.equal("inside")
			expect(HideSpotUtils.spotOf("cabinet")).to.equal("inside")
			expect(HideSpotUtils.spotOf("shelf")).to.equal(nil)
		end)
	end)

	describe("frames", function()
		it("sinks the body under a desk until its head clears the underside, facing out of the front", function()
			local frames = HideSpotUtils.frames("under", DESK, DESK_SIZE, STAND)
			local top = frames.hide.Position.Y + HideConstants.HEAD_ABOVE_ROOT
			expect(top <= 10 + DESK_SIZE.Y - HideConstants.UNDER_CLEARANCE + 1e-6).to.equal(true)
			local inDesk = DESK:PointToObjectSpace(frames.hide.Position)
			expect(math.abs(inDesk.X) < DESK_SIZE.X / 2 and math.abs(inDesk.Z) < DESK_SIZE.Z / 2).to.equal(true)
			expect(frames.hide.LookVector:Dot(DESK.LookVector)).to.be.near(1, 1e-6)
		end)

		it("stands the body inside a tall locker without sinking it", function()
			local frames = HideSpotUtils.frames("inside", LOCKER, LOCKER_SIZE, STAND)
			expect(frames.hide.Position.Y).to.be.near(STAND, 1e-6)
			expect(frames.hide.Position.X).to.be.near(0, 1e-6)
		end)

		it("peeks low out from under the desk, and at eye height out of the locker's front", function()
			local under = HideSpotUtils.frames("under", DESK, DESK_SIZE, STAND)
			expect(under.peek.Position.Y).to.be.near(10 + HideConstants.UNDER_EYE, 1e-6)
			expect(under.peek.LookVector:Dot(DESK.LookVector)).to.be.near(1, 1e-6)
			local inside = HideSpotUtils.frames("inside", LOCKER, LOCKER_SIZE, STAND)
			expect(inside.peek.Position.Y).to.be.near(LOCKER_SIZE.Y - HideConstants.INSIDE_EYE_FROM_TOP, 1e-6)
			expect(inside.peek.Position.Z < 0).to.equal(true)
			expect(inside.peek.Position.Z > -LOCKER_SIZE.Z / 2).to.equal(true)
		end)

		it("puts the prompt on the front face and tries the front exit first", function()
			local frames = HideSpotUtils.frames("inside", LOCKER, LOCKER_SIZE, STAND)
			expect(frames.prompt.Z).to.be.near(-LOCKER_SIZE.Z / 2 - 0.3, 1e-6)
			expect(#frames.exits).to.equal(4)
			local front = frames.exits[1].Position
			expect(front.Z).to.be.near(-(LOCKER_SIZE.Z / 2 + HideConstants.EXIT_GAP), 1e-6)
			expect(front.Y).to.be.near(STAND, 1e-6)
			expect(frames.exits[2].Position.Z > 0).to.equal(true)
		end)

		it("keeps a short cabinet's body inside its height too", function()
			local size = Vector3.new(1.9, 4.2, 2)
			local frames = HideSpotUtils.frames("inside", CFrame.new(0, 2.1, 0), size, STAND)
			expect(
				frames.hide.Position.Y + HideConstants.HEAD_ABOVE_ROOT <= size.Y - HideConstants.UNDER_CLEARANCE + 1e-6
			).to.equal(true)
		end)
	end)
end
