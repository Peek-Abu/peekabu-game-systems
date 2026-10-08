--!strict
--[=[
	Unit tests for CollisionShapeUtils (R6 spec 2026-10-08 §4, §5): capsule parts, resting-on, push
	direction, slide-off velocity and the range band.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)
local CollisionShapeUtils = require(script.Parent.CollisionShapeUtils)

return function()
	local C = CollisionConstants
	local HEAD = C.TOP - C.BOTTOM -- my root height when my feet are exactly on their head top (theirs at Y 0)

	local function near(a, b)
		return math.abs(a - b) < 1e-4 -- CFrame and Vector3 components are float32
	end

	local function nearVector(a, b)
		return (a - b).Magnitude < 1e-4
	end

	describe("capsule", function()
		it("joins two balls and an upright cylinder into exactly bottom..top at the radius", function()
			local parts = CollisionShapeUtils.capsule(C.RADIUS, C.BOTTOM, C.TOP)
			expect(#parts).to.equal(3)
			local bottom, middle, top = parts[1], parts[2], parts[3]
			expect(bottom.shape).to.equal(Enum.PartType.Ball)
			expect(middle.shape).to.equal(Enum.PartType.Cylinder)
			expect(top.shape).to.equal(Enum.PartType.Ball)
			expect(near(bottom.size.X, 2 * C.RADIUS)).to.equal(true)
			expect(near(top.size.X, 2 * C.RADIUS)).to.equal(true)
			expect(near(middle.size.Y, 2 * C.RADIUS)).to.equal(true)
			expect(near(bottom.offset.Position.Y - C.RADIUS, C.BOTTOM)).to.equal(true)
			expect(near(top.offset.Position.Y + C.RADIUS, C.TOP)).to.equal(true)
			-- the cylinder's axis is X; stood upright it runs along Y between the two ball centres
			expect(near(middle.offset.RightVector.Y, 1)).to.equal(true)
			expect(near(middle.size.X, top.offset.Position.Y - bottom.offset.Position.Y)).to.equal(true)
			expect(near(middle.offset.Position.Y, (top.offset.Position.Y + bottom.offset.Position.Y) / 2)).to.equal(
				true
			)
		end)

		it("matches the measured rig numbers", function()
			local parts = CollisionShapeUtils.capsule(C.RADIUS, C.BOTTOM, C.TOP)
			expect(math.abs(parts[1].offset.Position.Y - -2.95) < 1e-4).to.equal(true)
			expect(math.abs(parts[2].offset.Position.Y - -1.26) < 1e-4).to.equal(true)
			expect(math.abs(parts[2].size.X - 3.38) < 1e-4).to.equal(true)
			expect(math.abs(parts[3].offset.Position.Y - 0.43) < 1e-4).to.equal(true)
		end)
	end)

	describe("restingOn", function()
		local theirs = Vector3.zero

		it("is true with my feet on their head top, inside two radii", function()
			expect(CollisionShapeUtils.restingOn(Vector3.new(0.5, HEAD, 0), 0, theirs)).to.equal(true)
		end)

		it("holds inside the gap tolerance and fails just outside it", function()
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD + 0.59, 0), 0, theirs)).to.equal(true)
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD - 0.59, 0), 0, theirs)).to.equal(true)
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD + 0.61, 0), 0, theirs)).to.equal(false)
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD - 0.61, 0), 0, theirs)).to.equal(false)
		end)

		it("fails at two radii or more horizontally", function()
			expect(CollisionShapeUtils.restingOn(Vector3.new(2.19, HEAD, 0), 0, theirs)).to.equal(true)
			expect(CollisionShapeUtils.restingOn(Vector3.new(2.21, HEAD, 0), 0, theirs)).to.equal(false)
			expect(CollisionShapeUtils.restingOn(Vector3.new(1.6, HEAD, 1.6), 0, theirs)).to.equal(false)
		end)

		it("fails while rising faster than the limit, holds while falling", function()
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD, 0), 1, theirs)).to.equal(true)
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD, 0), 1.01, theirs)).to.equal(false)
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD, 0), -20, theirs)).to.equal(true)
		end)

		it("is false when standing beside them on the same floor", function()
			expect(CollisionShapeUtils.restingOn(Vector3.new(1.5, 0, 0), 0, theirs)).to.equal(false)
		end)
	end)

	describe("pushDirection", function()
		it("points horizontally away from their centre", function()
			local direction = CollisionShapeUtils.pushDirection(Vector3.new(3, 5, 4), Vector3.zero, Vector3.zAxis)
			expect(nearVector(direction, Vector3.new(0.6, 0, 0.8))).to.equal(true)
		end)

		it("follows my horizontal facing when I'm over their centre", function()
			local look = Vector3.new(0, -0.6, -0.8)
			local direction = CollisionShapeUtils.pushDirection(Vector3.new(0.1, 5, 0), Vector3.zero, look)
			expect(nearVector(direction, Vector3.new(0, 0, -1))).to.equal(true)
		end)

		it("falls back to +X when I'm over their centre looking straight up", function()
			local direction = CollisionShapeUtils.pushDirection(Vector3.new(0, 5, 0), Vector3.zero, Vector3.yAxis)
			expect(nearVector(direction, Vector3.xAxis)).to.equal(true)
		end)
	end)

	describe("slideOffVelocity", function()
		it("raises the outward speed to the slide-off speed, keeping the rest", function()
			local pushed = CollisionShapeUtils.slideOffVelocity(Vector3.new(0, -3, 0), Vector3.xAxis)
			expect(nearVector(pushed, Vector3.new(12, -3, 0))).to.equal(true)
			local inward = CollisionShapeUtils.slideOffVelocity(Vector3.new(-4, 0, 2), Vector3.xAxis)
			expect(nearVector(inward, Vector3.new(12, 0, 2))).to.equal(true)
		end)

		it("returns nil when already moving out at least that fast", function()
			expect(CollisionShapeUtils.slideOffVelocity(Vector3.new(12, 0, 0), Vector3.xAxis)).to.equal(nil)
			expect(CollisionShapeUtils.slideOffVelocity(Vector3.new(15, 0, 0), Vector3.xAxis)).to.equal(nil)
		end)
	end)

	describe("nextSolid", function()
		it("turns solid at the solid range or closer", function()
			expect(CollisionShapeUtils.nextSolid(false, 20 * 20)).to.equal(true)
			expect(CollisionShapeUtils.nextSolid(false, 20.01 * 20.01)).to.equal(false)
			expect(CollisionShapeUtils.nextSolid(false, 21 * 21)).to.equal(false)
		end)

		it("stays solid through the buffer and releases beyond it", function()
			expect(CollisionShapeUtils.nextSolid(true, 21 * 21)).to.equal(true)
			expect(CollisionShapeUtils.nextSolid(true, 22 * 22)).to.equal(true)
			expect(CollisionShapeUtils.nextSolid(true, 22.01 * 22.01)).to.equal(false)
		end)
	end)
end
