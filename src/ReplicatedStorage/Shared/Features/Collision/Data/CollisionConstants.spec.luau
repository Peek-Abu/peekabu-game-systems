--!strict
--[=[
	Unit tests for CollisionConstants (R6 spec 2026-10-08 §3): the size table's invariants.
]=]

local CollisionConstants = require(script.Parent.CollisionConstants)

return function()
	local C = CollisionConstants

	it("releases farther out than it turns solid, and turns solid well before contact", function()
		expect(C.RELEASE_RANGE > C.SOLID_RANGE).to.equal(true)
		expect(C.SOLID_RANGE > 2 * C.RADIUS).to.equal(true)
	end)

	it("spans feet to head top with room for both end caps", function()
		expect(C.BOTTOM < C.TOP).to.equal(true)
		expect(C.TOP - C.BOTTOM > 2 * C.RADIUS).to.equal(true)
	end)

	it("keeps the slide-off push under walk speed", function()
		expect(C.SLIDE_OFF_SPEED > 0).to.equal(true)
		expect(C.SLIDE_OFF_SPEED < 16).to.equal(true)
	end)

	it("names two distinct groups and a frictionless material", function()
		expect(C.PUPPET_GROUP).never.to.equal(C.SELF_GROUP)
		expect(C.FRICTIONLESS.Friction).to.equal(0)
		expect(C.FRICTIONLESS.FrictionWeight).to.equal(100)
	end)
end
