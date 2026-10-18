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

	describe("checkRoute", function()
		local function routed()
			local layout = fixture()
			table.insert(layout.markers, { id = "b.patrol.1", room = "b", kind = "patrol", x = 25, z = 5 })
			table.insert(layout.markers, { id = "b.patrol.2", room = "b", kind = "patrol", x = 35, z = 5 })
			table.insert(layout.markers, { id = "b.patrol.3", room = "b", kind = "patrol", x = 35, z = 15 })
			table.insert(layout.markers, { id = "b.rest.1", room = "b", kind = "rest", x = 25, z = 15 })
			layout.route = { "b.patrol.1", "b.patrol.2", "b.patrol.3" }
			layout.rest = "b.rest.1"
			return layout
		end

		it("accepts the authored office's route", function()
			local ok, reason = OfficeLayoutRules.checkRoute(OfficeLayoutConstants.LAYOUT)
			expect(reason).to.equal(nil)
			expect(ok).to.equal(true)
		end)

		it("accepts a small valid route", function()
			expect(OfficeLayoutRules.checkRoute(routed())).to.equal(true)
		end)

		it("refuses a route that is too short", function()
			local layout = routed()
			layout.route = { "b.patrol.1", "b.patrol.2" }
			local ok, reason = OfficeLayoutRules.checkRoute(layout)
			expect(ok).to.equal(false)
			expect(string.find(reason, "route", 1, true) ~= nil).to.equal(true)
		end)

		it("refuses a route point that is not a patrol marker", function()
			local layout = routed()
			layout.route[2] = "b.pile.1"
			local _, reason = OfficeLayoutRules.checkRoute(layout)
			expect(reason).to.equal('route point "b.pile.1" is not a patrol marker')
		end)

		it("refuses a route point in the safe start room", function()
			local layout = routed()
			table.insert(layout.markers, { id = "a.patrol.1", room = "a", kind = "patrol", x = 10, z = 10 })
			layout.route[3] = "a.patrol.1"
			local _, reason = OfficeLayoutRules.checkRoute(layout)
			expect(reason).to.equal('route point "a.patrol.1" is in the safe start room')
		end)

		it("refuses a missing rest point", function()
			local layout = routed()
			layout.rest = "b.rest.9"
			local _, reason = OfficeLayoutRules.checkRoute(layout)
			expect(reason).to.equal('rest point "b.rest.9" is not a rest marker')
		end)
	end)
end
