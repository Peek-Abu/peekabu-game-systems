local OfficeAmbienceUtils = require(script.Parent.OfficeAmbienceUtils)

local EMITTERS = {
	{ kind = "phone", position = Vector3.new(0, 0, 0) },
	{ kind = "typing", position = Vector3.new(5, 0, 0) },
	{ kind = "phone", position = Vector3.new(100, 0, 0) },
	{ kind = "elevator", position = Vector3.new(0, 0, 200) },
}

return function()
	describe("empty", function()
		it("is empty when nobody is within the radius", function()
			expect(OfficeAmbienceUtils.empty(Vector3.zero, { Vector3.new(40, 0, 0) }, 28)).to.equal(true)
			expect(OfficeAmbienceUtils.empty(Vector3.zero, { Vector3.new(40, 0, 0), Vector3.new(10, 0, 0) }, 28)).to.equal(
				false
			)
			expect(OfficeAmbienceUtils.empty(Vector3.zero, {}, 28)).to.equal(true)
		end)
	end)

	describe("pick", function()
		it("rings a phone only in an empty room", function()
			local crew = { Vector3.new(2, 0, 0) }
			expect(OfficeAmbienceUtils.pick(EMITTERS, "phone", crew, 28, 0)).to.equal(3)
			expect(OfficeAmbienceUtils.pick(EMITTERS, "phone", crew, 28, 0.99)).to.equal(3)
		end)

		it("chooses among the empty ones by the roll", function()
			expect(OfficeAmbienceUtils.pick(EMITTERS, "phone", {}, 28, 0)).to.equal(1)
			expect(OfficeAmbienceUtils.pick(EMITTERS, "phone", {}, 28, 0.99)).to.equal(3)
		end)

		it("rings nothing when every room of that kind has someone in it", function()
			local crew = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }
			expect(OfficeAmbienceUtils.pick(EMITTERS, "phone", crew, 28, 0.5)).to.equal(nil)
			expect(OfficeAmbienceUtils.pick(EMITTERS, "fax", {}, 28, 0.5)).to.equal(nil)
		end)
	end)

	describe("typingStops", function()
		it("stops the typing when you come within the radius", function()
			expect(OfficeAmbienceUtils.typingStops(19, 20)).to.equal(true)
			expect(OfficeAmbienceUtils.typingStops(20, 20)).to.equal(true)
			expect(OfficeAmbienceUtils.typingStops(21, 20)).to.equal(false)
		end)
	end)

	describe("delay", function()
		it("waits between the minimum and the maximum", function()
			expect(OfficeAmbienceUtils.delay(0, 20, 50)).to.equal(20)
			expect(OfficeAmbienceUtils.delay(1, 20, 50)).to.equal(50)
			expect(OfficeAmbienceUtils.delay(0.5, 20, 50)).to.equal(35)
			expect(OfficeAmbienceUtils.delay(7, 20, 50)).to.equal(50)
		end)
	end)

	describe("sweeteners", function()
		it("places a sweetener on a ring around the listener, at ear height", function()
			local listener = Vector3.new(10, 5, -3)
			for _, roll in { { 0, 0 }, { 0.25, 1 }, { 0.6, 0.5 }, { 0.99, 0.2 } } do
				local at = OfficeAmbienceUtils.sweetenerAt(listener, roll[1], roll[2], 12, 30)
				local flat = Vector3.new(at.X - listener.X, 0, at.Z - listener.Z).Magnitude
				expect(at.Y).to.equal(listener.Y)
				expect(flat >= 12 - 1e-6 and flat <= 30 + 1e-6).to.equal(true)
			end
			local near = OfficeAmbienceUtils.sweetenerAt(listener, 0, 0, 12, 30)
			local far = OfficeAmbienceUtils.sweetenerAt(listener, 0, 1, 12, 30)
			expect((near - listener).Magnitude).to.be.near(12, 1e-6)
			expect((far - listener).Magnitude).to.be.near(30, 1e-6)
		end)

		it("picks each variant of a sweetener, never past the last", function()
			expect(OfficeAmbienceUtils.variant(0, 3)).to.equal(1)
			expect(OfficeAmbienceUtils.variant(0.5, 3)).to.equal(2)
			expect(OfficeAmbienceUtils.variant(0.999, 3)).to.equal(3)
			expect(OfficeAmbienceUtils.variant(1, 3)).to.equal(3)
			expect(OfficeAmbienceUtils.variant(0.4, 1)).to.equal(1)
		end)

		it("never repeats the last variant when there is a choice", function()
			for roll = 0, 0.99, 0.07 do
				local index = OfficeAmbienceUtils.variant(roll, 3, 2)
				expect(index).never.to.equal(2)
				expect(index >= 1 and index <= 3).to.equal(true)
			end
			expect(OfficeAmbienceUtils.variant(0, 3, 1)).to.equal(2)
			expect(OfficeAmbienceUtils.variant(0.999, 3, 3)).to.equal(2)
			-- A lone variant repeats; a last out of range is ignored.
			expect(OfficeAmbienceUtils.variant(0.5, 1, 1)).to.equal(1)
			expect(OfficeAmbienceUtils.variant(0, 3, 9)).to.equal(1)
		end)
	end)

	describe("loopOn", function()
		it("starts a fixed emitter's loop within the radius", function()
			expect(OfficeAmbienceUtils.loopOn(40, 40, 10, false)).to.equal(true)
			expect(OfficeAmbienceUtils.loopOn(41, 40, 10, false)).to.equal(false)
		end)

		it("keeps a playing loop until the radius plus the margin, so it does not flicker at the edge", function()
			expect(OfficeAmbienceUtils.loopOn(45, 40, 10, true)).to.equal(true)
			expect(OfficeAmbienceUtils.loopOn(50, 40, 10, true)).to.equal(true)
			expect(OfficeAmbienceUtils.loopOn(51, 40, 10, true)).to.equal(false)
		end)
	end)
	describe("sources", function()
		local box = CFrame.new(100, 5, 0)
		local size = Vector3.new(40, 10, 2)

		it("measures the distance to an emitter volume's nearest point (0 inside)", function()
			expect(OfficeAmbienceUtils.boxDistance(Vector3.new(100, 5, 0), box, size)).to.equal(0)
			expect(OfficeAmbienceUtils.boxDistance(Vector3.new(110, 5, 11), box, size)).to.be.near(10)
			expect(OfficeAmbienceUtils.boxDistance(Vector3.new(130, 5, 0), box, size)).to.be.near(10)
		end)

		it("measures along a turned volume", function()
			local turned = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
			-- Turned 90 degrees, the 40-stud length runs along Z.
			expect(OfficeAmbienceUtils.boxDistance(Vector3.new(0, 0, 25), turned, size)).to.be.near(5)
		end)

		it("finds the volume's nearest point to a listener (the road side's traffic plays from there)", function()
			local near = OfficeAmbienceUtils.nearestInBox(Vector3.new(110, 50, 30), box, size)
			expect(near.X).to.be.near(110)
			expect(near.Y).to.be.near(10)
			expect(near.Z).to.be.near(1)
		end)

		it("places a one-shot inside the volume by three rolls", function()
			local low = OfficeAmbienceUtils.pointInBox(box, size, 0, 0, 0)
			local high = OfficeAmbienceUtils.pointInBox(box, size, 1, 1, 1)
			expect(low.X).to.be.near(80)
			expect(high.X).to.be.near(120)
			expect(high.Y).to.be.near(10)
			for _, r in { 0.1, 0.5, 0.9 } do
				expect(OfficeAmbienceUtils.boxDistance(OfficeAmbienceUtils.pointInBox(box, size, r, r, r), box, size)).to.equal(
					0
				)
			end
		end)

		it("keeps a rolled point within the sound's reach, pulled toward the volume's nearest point", function()
			-- A 400-stud road: a roll at its far end is beyond a 100-stud reach from a listener near one end.
			local road = CFrame.new(200, 0, 0)
			local roadSize = Vector3.new(400, 2, 10)
			local listener = Vector3.new(-30, 0, 0)
			local far = OfficeAmbienceUtils.pointInReach(listener, road, roadSize, 100, 1, 0.5, 0.5)
			expect((far - listener).Magnitude <= 100 * 0.8 + 1e-6).to.equal(true)
			expect(OfficeAmbienceUtils.boxDistance(far, road, roadSize)).to.be.near(0)
			-- A roll already in reach is kept.
			local near = OfficeAmbienceUtils.pointInReach(listener, road, roadSize, 100, 0, 0.5, 0.5)
			expect(near.X).to.be.near(0)
			-- Out of reach altogether: the volume's nearest point.
			local edge = OfficeAmbienceUtils.pointInReach(Vector3.new(-500, 0, 0), road, roadSize, 100, 1, 0.5, 0.5)
			expect(edge.X).to.be.near(0)
		end)

		it("picks among the sources within the radius by a roll, none when all are too far", function()
			expect(OfficeAmbienceUtils.pickNear({ 50, 10, 200, 30 }, 60, 0)).to.equal(1)
			expect(OfficeAmbienceUtils.pickNear({ 50, 10, 200, 30 }, 60, 0.999)).to.equal(4)
			expect(OfficeAmbienceUtils.pickNear({ 50, 10, 200, 30 }, 60, 0.5)).to.equal(2)
			expect(OfficeAmbienceUtils.pickNear({ 200, 300 }, 60, 0.5)).to.equal(nil)
			expect(OfficeAmbienceUtils.pickNear({}, 60, 0.5)).to.equal(nil)
		end)
	end)
end
