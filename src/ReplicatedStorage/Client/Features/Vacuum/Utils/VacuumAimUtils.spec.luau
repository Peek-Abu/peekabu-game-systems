local VacuumAimUtils = require(script.Parent.VacuumAimUtils)

local ORIGIN = Vector3.new(0, 3, 0)
local LOOK = Vector3.new(0, -0.3, -1)

return function()
	it("picks the nearest pile in front within range", function()
		local index = VacuumAimUtils.pick(ORIGIN, LOOK, {
			Vector3.new(0, 0.5, -7),
			Vector3.new(1, 0.5, -4),
		}, 8, 0.35)
		expect(index).to.equal(2)
	end)

	it("ignores piles behind the player", function()
		expect(VacuumAimUtils.pick(ORIGIN, LOOK, { Vector3.new(0, 0.5, 5) }, 8, 0.35)).to.equal(nil)
	end)

	it("ignores piles out of range, counting height", function()
		expect(VacuumAimUtils.pick(ORIGIN, LOOK, { Vector3.new(0, 0.5, -9) }, 8, 0.35)).to.equal(nil)
		expect(VacuumAimUtils.pick(ORIGIN, LOOK, { Vector3.new(0, 12, -2) }, 8, 0.35)).to.equal(nil)
	end)

	it("counts a pile underfoot whatever the camera faces", function()
		expect(VacuumAimUtils.pick(ORIGIN, LOOK, { Vector3.new(0.5, 0.5, 0.5) }, 8, 0.35)).to.equal(1)
	end)

	it("returns nil with no piles", function()
		expect(VacuumAimUtils.pick(ORIGIN, LOOK, {}, 8, 0.35)).to.equal(nil)
	end)
end
