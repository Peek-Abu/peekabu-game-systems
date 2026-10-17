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
	end)
end
