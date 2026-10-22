local OfficeKitRules = require(script.Parent.OfficeKitRules)

-- A clean 30 x 24 kit: a desk (chair strip behind it), a shelf on the back wall, three piles, a patrol point.
local function fixture()
	return {
		id = "fixture",
		roomType = "pods",
		name = "Fixture",
		size = "M",
		width = 30,
		depth = 24,
		door = { offset = 15, width = 6, kind = "solid" },
		markers = {
			{ kind = "desk", x = 8, z = 8, rotation = 0 },
			{ kind = "shelf", x = 22, z = 20, rotation = 0 },
			{ kind = "pile", x = 4, z = 20 },
			{ kind = "pile", x = 12, z = 18 },
			{ kind = "pile", x = 26, z = 8 },
			{ kind = "patrol", x = 15, z = 15 },
		},
	}
end

local function hasError(errors, fragment)
	for _, message in errors do
		if string.find(message, fragment, 1, true) then
			return true
		end
	end
	return false
end

return function()
	it("passes a clean kit", function()
		local ok, errors = OfficeKitRules.check(fixture())
		expect(ok).to.equal(true)
		expect(#errors).to.equal(0)
	end)

	it("flags a desk moved onto a shelf", function()
		local kit = fixture()
		kit.markers[1].x = 22
		kit.markers[1].z = 20
		local ok, errors = OfficeKitRules.check(kit)
		expect(ok).to.equal(false)
		expect(hasError(errors, "overlaps")).to.equal(true)
	end)

	it("flags furniture outside the walls", function()
		local kit = fixture()
		kit.markers[2].x = 29
		local _, errors = OfficeKitRules.check(kit)
		expect(hasError(errors, "outside the walls")).to.equal(true)
	end)

	it("flags a desk without room for its chair", function()
		local kit = fixture()
		-- One stud off the back wall, chair side toward it.
		kit.markers[1].x = 8
		kit.markers[1].z = 24 - 1 - 2.475
		local _, errors = OfficeKitRules.check(kit)
		expect(hasError(errors, "chair")).to.equal(true)
	end)

	it("flags a plant in the door approach", function()
		local kit = fixture()
		table.insert(kit.markers, { kind = "plant", x = 15, z = 2.5 })
		local _, errors = OfficeKitRules.check(kit)
		expect(hasError(errors, "door approach")).to.equal(true)
	end)

	it("flags a kit with no patrol marker", function()
		local kit = fixture()
		table.remove(kit.markers, 6)
		local _, errors = OfficeKitRules.check(kit)
		expect(hasError(errors, "patrol")).to.equal(true)
	end)

	it("flags a breakout with no rest marker", function()
		local kit = fixture()
		kit.roomType = "breakout"
		local _, errors = OfficeKitRules.check(kit)
		expect(hasError(errors, "rest")).to.equal(true)
	end)

	it("flags fewer piles than a dirty room needs", function()
		local kit = fixture()
		table.remove(kit.markers, 5)
		local _, errors = OfficeKitRules.check(kit)
		expect(hasError(errors, "pile")).to.equal(true)
	end)

	it("flags a pile crowding furniture", function()
		local kit = fixture()
		kit.markers[3].x = 22
		kit.markers[3].z = 18
		local _, errors = OfficeKitRules.check(kit)
		expect(hasError(errors, "crowds")).to.equal(true)
	end)
end
