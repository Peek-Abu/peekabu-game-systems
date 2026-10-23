local ServerScriptService = game:GetService("ServerScriptService")

local OfficeLayoutRules = require(script.Parent.OfficeLayoutRules)
local OfficeLayoutUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutUtils)
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
		it("is valid once the furniture that no longer fits is dropped", function()
			-- The desks and tables grew (HIDE_FURNITURE_SCALE): the break and open-plan tables now crowd loot spots.
			local layout = OfficeLayoutUtils.dropUnfit(OfficeLayoutConstants.LAYOUT, OfficeLayoutRules)
			local ok, errors = OfficeLayoutRules.validate(layout)
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

		it("accepts flush rotated furniture but rejects footprints through walls", function()
			local layout = fixture()
			layout.markers[2] =
				{ id = "b.counter", room = "b", kind = "counter", x = 21.75, z = 10, rotation = -math.pi / 2 }
			local ok, errors = OfficeLayoutRules.validate(layout)
			if not ok then
				error(table.concat(errors, "; "))
			end
			expect(ok).to.equal(true)
			layout.markers[2].x = 20.5
			local _, invalid = OfficeLayoutRules.validate(layout)
			expect(hasError(invalid, 'marker "b.counter" is not inside')).to.equal(true)
		end)

		it("keeps ordinary loot away from walls even with an explicit rotation", function()
			local layout = fixture()
			layout.markers[2] = { id = "b.item", room = "b", kind = "item", x = 20.8, z = 10, rotation = 0 }
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'marker "b.item" is not inside')).to.equal(true)
		end)

		it("reports a marker naming a missing room", function()
			local layout = fixture()
			layout.markers[2].room = "z"
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'marker "b.pile.1" names a missing room')).to.equal(true)
		end)

		it("reports a wall prop hung over a door on its wall, and accepts one beside it", function()
			local layout = fixture()
			table.insert(layout.markers, {
				id = "b.prop.1",
				room = "b",
				kind = "prop",
				art = "artFrame",
				x = 20.635,
				z = 10,
				rotation = math.pi / 2,
			})
			local ok, errors = OfficeLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, 'wall prop "b.prop.1" hangs over a door or facade of room "b"')).to.equal(true)
			-- 4 wide along the wall: z 14..18 clears the door's 7..13.
			layout.markers[#layout.markers].z = 16
			local clear, clearErrors = OfficeLayoutRules.validate(layout)
			expect(table.concat(clearErrors, "; ")).to.equal("")
			expect(clear).to.equal(true)
		end)

		it("reports a wall prop hung over a facade on its wall, and accepts one beside it", function()
			local layout = fixture()
			layout.facades = { { room = "a", x = 0, z = 10, width = 8, kind = "entrance" } }
			table.insert(layout.markers, {
				id = "a.prop.1",
				room = "a",
				kind = "prop",
				art = "artFrame",
				x = 0.635,
				z = 10,
				rotation = -math.pi / 2,
			})
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'wall prop "a.prop.1" hangs over a door or facade of room "a"')).to.equal(true)
			-- z 15..19 clears the facade's 6..14.
			layout.markers[#layout.markers].z = 17
			local ok, clearErrors = OfficeLayoutRules.validate(layout)
			expect(table.concat(clearErrors, "; ")).to.equal("")
			expect(ok).to.equal(true)
		end)

		it("reports surface furniture crowded by a floor loot spot", function()
			local layout = fixture()
			table.insert(layout.markers, { id = "b.table.1", room = "b", kind = "table", x = 30, z = 14 })
			table.insert(layout.markers, { id = "b.item.1", room = "b", kind = "item", x = 31, z = 15 })
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'surface marker "b.table.1" crowds item marker "b.item.1"')).to.equal(true)
		end)

		it("uses rotated furniture footprints for item clearance", function()
			local layout = fixture()
			layout.markers = {
				{ id = "b.counter", room = "b", kind = "counter", x = 30, z = 10, rotation = math.pi / 2 },
				{ id = "b.item", room = "b", kind = "item", x = 30, z = 13, rotation = 0 },
			}
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'surface marker "b.counter" crowds')).to.equal(true)
		end)

		it("reports surface furniture overlapping a desk", function()
			local layout = fixture()
			table.insert(layout.markers, { id = "b.desk.1", room = "b", kind = "desk", x = 30, z = 10 })
			table.insert(layout.markers, { id = "b.cabinet.1", room = "b", kind = "cabinet", x = 31, z = 10 })
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'surface marker "b.cabinet.1" overlaps "b.desk.1"')).to.equal(true)
		end)

		it("treats a floor prop as furniture: walls, loot clearance and desk overlap", function()
			local layout = fixture()
			table.insert(layout.markers, { id = "b.prop.1", room = "b", kind = "prop", art = "sofa", x = 39, z = 10 })
			local _, outside = OfficeLayoutRules.validate(layout)
			expect(hasError(outside, 'marker "b.prop.1" is not inside room "b"')).to.equal(true)

			layout = fixture()
			table.insert(layout.markers, { id = "b.prop.1", room = "b", kind = "prop", art = "sofa", x = 30, z = 10 })
			table.insert(layout.markers, { id = "b.item.1", room = "b", kind = "item", x = 30, z = 12.5 })
			table.insert(layout.markers, { id = "b.desk.1", room = "b", kind = "desk", x = 33, z = 10 })
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'surface marker "b.prop.1" crowds item marker "b.item.1"')).to.equal(true)
			expect(hasError(errors, 'surface marker "b.prop.1" overlaps "b.desk.1"')).to.equal(true)
		end)

		it("lets a desk, loot and a pile stand on a flat floor prop (a rug), but keeps it inside its room", function()
			local layout = fixture()
			table.insert(layout.markers, { id = "b.prop.1", room = "b", kind = "prop", art = "rug", x = 30, z = 10 })
			table.insert(layout.markers, { id = "b.desk.1", room = "b", kind = "desk", x = 30, z = 13 })
			table.insert(layout.markers, { id = "b.item.1", room = "b", kind = "item", x = 34, z = 7 })
			local ok, errors = OfficeLayoutRules.validate(layout)
			expect(errors[1]).to.equal(nil)
			expect(ok).to.equal(true)
			expect(OfficeLayoutRules.markerFits(layout, layout.markers[#layout.markers - 1])).to.equal(true)
			layout.markers[3].x = 36
			local _, outside = OfficeLayoutRules.validate(layout)
			expect(hasError(outside, 'marker "b.prop.1" is not inside room "b"')).to.equal(true)
		end)

		it("lets a wall prop hang over loot and rejects a prop with no sized art", function()
			local layout = fixture()
			table.insert(
				layout.markers,
				{ id = "b.prop.1", room = "b", kind = "prop", art = "artFrame", x = 30, z = 19.365 }
			)
			table.insert(layout.markers, { id = "b.item.1", room = "b", kind = "item", x = 30, z = 18 })
			local ok = OfficeLayoutRules.validate(layout)
			expect(ok).to.equal(true)
			table.insert(
				layout.markers,
				{ id = "b.prop.2", room = "b", kind = "prop", art = "nonsense", x = 25, z = 5 }
			)
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'prop marker "b.prop.2" names no sized art')).to.equal(true)
		end)

		it("sizes restyled furniture by its art: a conferenceTable crosses a wall its kind size clears", function()
			local layout = fixture()
			table.insert(layout.markers, { id = "b.table.1", room = "b", kind = "table", x = 30, z = 10, rotation = 0 })
			local _, plain = OfficeLayoutRules.validate(layout)
			expect(hasError(plain, 'marker "b.table.1" is not inside room "b"')).to.equal(false)
			layout.markers[#layout.markers].x = 33.5
			layout.markers[#layout.markers].art = "conferenceTable"
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'marker "b.table.1" is not inside room "b"')).to.equal(true)
		end)

		it("takes no floor space for a desk-top prop on a desk", function()
			local layout = fixture()
			table.insert(layout.markers, { id = "b.desk.1", room = "b", kind = "desk", x = 30, z = 10, rotation = 0 })
			table.insert(
				layout.markers,
				{ id = "b.prop.1", room = "b", kind = "prop", art = "deskPlant", x = 30, z = 10, rotation = 0 }
			)
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, "b.prop.1")).to.equal(false)
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

		it("accepts a route point in the loading bay, clear of the truck", function()
			local layout = routed()
			table.insert(layout.markers, { id = "a.patrol.1", room = "a", kind = "patrol", x = 15, z = 5 })
			layout.route[3] = "a.patrol.1"
			local ok, reason = OfficeLayoutRules.checkRoute(layout)
			expect(reason).to.equal(nil)
			expect(ok).to.equal(true)
		end)

		it("refuses a route point on the truck (the safe box)", function()
			local layout = routed()
			table.insert(layout.markers, { id = "a.patrol.1", room = "a", kind = "patrol", x = 5, z = 14 })
			layout.route[3] = "a.patrol.1"
			local _, reason = OfficeLayoutRules.checkRoute(layout)
			expect(reason).to.equal('route point "a.patrol.1" is on the truck')
		end)

		it("refuses a rest point in the loading bay", function()
			local layout = routed()
			table.insert(layout.markers, { id = "a.rest.1", room = "a", kind = "rest", x = 15, z = 5 })
			layout.rest = "a.rest.1"
			local _, reason = OfficeLayoutRules.checkRoute(layout)
			expect(reason).to.equal('rest point "a.rest.1" is in the loading bay')
		end)

		it("refuses a missing rest point", function()
			local layout = routed()
			layout.rest = "b.rest.9"
			local _, reason = OfficeLayoutRules.checkRoute(layout)
			expect(reason).to.equal('rest point "b.rest.9" is not a rest marker')
		end)
	end)

	describe("checkHideSpots", function()
		local function withDesks(count)
			local layout = fixture()
			for index = 1, count do
				table.insert(layout.markers, { id = `b.desk.{index}`, room = "b", kind = "desk", x = 30, z = 10 })
			end
			return layout
		end

		it("refuses seven hiding places", function()
			local ok, reason = OfficeLayoutRules.checkHideSpots(withDesks(7))
			expect(ok).to.equal(false)
			expect(string.find(reason, "hide", 1, true) ~= nil).to.equal(true)
		end)

		it("accepts eight, counting desks and closets together", function()
			expect(OfficeLayoutRules.checkHideSpots(withDesks(8))).to.equal(true)
			local mixed = withDesks(5)
			for index = 1, 3 do
				table.insert(mixed.markers, { id = `b.closet.{index}`, room = "b", kind = "closet", x = 30, z = 10 })
			end
			expect(OfficeLayoutRules.checkHideSpots(mixed)).to.equal(true)
		end)
	end)

	describe("checkWalk", function()
		-- Six rooms in a row, 40 studs each; the doors sit on the shared walls at x = 40 .. 200.
		local function chain()
			local layout = fixture()
			layout.startRoom = "r1"
			layout.rooms = {}
			layout.doors = {}
			for index = 1, 6 do
				table.insert(layout.rooms, {
					id = `r{index}`,
					name = "R",
					minX = (index - 1) * 40,
					maxX = index * 40,
					minZ = 0,
					maxZ = 20,
				})
				if index > 1 then
					table.insert(
						layout.doors,
						{ a = `r{index - 1}`, b = `r{index}`, x = (index - 1) * 40, z = 10, width = 6 }
					)
				end
			end
			return layout
		end

		it("fails naming the farthest room when the walk is too long", function()
			local ok, reason = OfficeLayoutRules.checkWalk(chain(), 100)
			expect(ok).to.equal(false)
			expect(string.find(reason, "r6", 1, true) ~= nil).to.equal(true)
		end)

		it("passes at a generous limit", function()
			expect(OfficeLayoutRules.checkWalk(chain(), 1000)).to.equal(true)
		end)

		it("measures from the last door to the room's centre", function()
			-- r6: door at x = 200 is 160 studs from the first door, its centre 20 further.
			expect(OfficeLayoutRules.checkWalk(chain(), 180)).to.equal(true)
			expect(OfficeLayoutRules.checkWalk(chain(), 179)).to.equal(false)
		end)

		it("fails a room no door reaches", function()
			local layout = chain()
			table.remove(layout.doors)
			local ok = OfficeLayoutRules.checkWalk(layout, 1000)
			expect(ok).to.equal(false)
		end)
	end)
end
