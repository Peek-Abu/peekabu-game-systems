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
end
