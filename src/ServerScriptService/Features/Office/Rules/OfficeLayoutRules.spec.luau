local ServerScriptService = game:GetService("ServerScriptService")

local OfficeLayoutRules = require(script.Parent.OfficeLayoutRules)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)

local function fixture()
	return {
		startRoom = "a",
		rooms = {
			{ id = "a", name = "A", minX = 0, minZ = 0, maxX = 20, maxZ = 20 },
			{ id = "b", name = "B", minX = 20, minZ = 0, maxX = 40, maxZ = 20 },
		},
		doors = { { a = "a", b = "b", x = 20, z = 10, width = 6 } },
		markers = {
			{ id = "a.spawn.1", room = "a", kind = "spawn", x = 5, z = 5 },
			{ id = "b.pile.1", room = "b", kind = "pile", x = 30, z = 10 },
		},
		truck = { minX = 2, minZ = 10, maxX = 8, maxZ = 18, clockX = 12, clockZ = 4 },
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
	describe("the authored office", function()
		it("is valid", function()
			local ok, errors = OfficeLayoutRules.validate(OfficeLayoutConstants.LAYOUT)
			if not ok then
				error(table.concat(errors, "\n"))
			end
			expect(ok).to.equal(true)
		end)

		it("has the markers the spawn roll needs", function()
			local ok, reason = OfficeLayoutRules.checkCapacity(OfficeLayoutConstants.LAYOUT)
			expect(reason).to.equal(nil)
			expect(ok).to.equal(true)
		end)
	end)

	describe("validate", function()
		it("accepts a small valid layout", function()
			local ok, errors = OfficeLayoutRules.validate(fixture())
			expect(ok).to.equal(true)
			expect(#errors).to.equal(0)
		end)

		it("reports a room nobody can reach", function()
			local layout = fixture()
			layout.doors = {}
			local ok, errors = OfficeLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, 'room "b" cannot be reached')).to.equal(true)
		end)

		it("reports a marker outside its room, including too close to a wall", function()
			local layout = fixture()
			layout.markers[2].x = 21
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'marker "b.pile.1" is not inside room "b"')).to.equal(true)
		end)

		it("reports a marker naming a missing room", function()
			local layout = fixture()
			layout.markers[2].room = "z"
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'marker "b.pile.1" names a missing room')).to.equal(true)
		end)

		it("reports a door that is not on a wall both rooms share", function()
			local layout = fixture()
			layout.doors[1].x = 10
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, "not on a wall both rooms share")).to.equal(true)
		end)

		it("reports a door narrower than the minimum", function()
			local layout = fixture()
			layout.doors[1].width = 2
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, "narrower than")).to.equal(true)
		end)

		it("reports overlapping rooms", function()
			local layout = fixture()
			layout.rooms[2].minX = 15
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'rooms "a" and "b" overlap')).to.equal(true)
		end)

		it("reports duplicate marker ids", function()
			local layout = fixture()
			layout.markers[2].id = "a.spawn.1"
			layout.markers[2].room = "a"
			layout.markers[2].x = 10
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'marker "a.spawn.1" is defined twice')).to.equal(true)
		end)

		it("reports a truck outside the start room", function()
			local layout = fixture()
			layout.truck.maxX = 30
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, "truck")).to.equal(true)
		end)
	end)

	describe("checkCapacity", function()
		it("refuses a layout with too few pile markers", function()
			local ok, reason = OfficeLayoutRules.checkCapacity(fixture())
			expect(ok).to.equal(false)
			expect(string.find(reason, "pile markers", 1, true) ~= nil).to.equal(true)
		end)
	end)
end
