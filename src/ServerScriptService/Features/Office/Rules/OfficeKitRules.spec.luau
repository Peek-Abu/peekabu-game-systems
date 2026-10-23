local OfficeKitRules = require(script.Parent.OfficeKitRules)
local Constants = require(game:GetService("ServerScriptService").Features.Office.Data.OfficeConstants)

-- A clean 30 x 24 kit: a desk (chair strip on its front, local -Z, toward the front wall), a shelf on the back
-- wall, three piles, a patrol point.
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
			{ kind = "desk", x = 6, z = 8, rotation = 0 },
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

	it("flags a desk without room for its chair on its front (local -Z)", function()
		local kit = fixture()
		-- One stud off the front wall's inner face, front (-Z) toward it; its back (+Z) is wide open.
		kit.markers[1].z = 0.5 + 1 + 2.475
		local _, errors = OfficeKitRules.check(kit)
		expect(hasError(errors, "chair")).to.equal(true)
	end)

	it("reads the chair strip on the desk's turned front", function()
		local kit = fixture()
		-- Turned half way, the front faces +Z: the same spot off the front wall is now clear.
		kit.markers[1].z = 0.5 + 1 + 2.475
		kit.markers[1].rotation = math.pi
		local ok, errors = OfficeKitRules.check(kit)
		expect(hasError(errors, "chair")).to.equal(false)
		expect(ok).to.equal(true)
	end)

	it("keeps furniture out of a swung leaf's reach behind a solid door, but not an open doorway", function()
		local kit = fixture()
		-- A 2 x 2 plant from 5 to 7 studs in: clear of DOOR_APPROACH (5), inside the 6-wide leaf's swing (6.5).
		table.insert(kit.markers, { kind = "plant", x = 15, z = 6 })
		local _, errors = OfficeKitRules.check(kit)
		expect(hasError(errors, "door approach")).to.equal(true)
		kit.door.kind = "open"
		local _, openErrors = OfficeKitRules.check(kit)
		expect(hasError(openErrors, "door approach")).to.equal(false)
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

	it(
		"flags floor furniture backed against the wall inside the trim clearance, and passes it one clearance off",
		function()
			local trim = Constants.SHELL.trimClearance
			local kit = fixture()
			-- The shelf (5 x 2) with its back on the back wall's plaster face (23.5): the wainscot and rail run into it.
			kit.markers[2].z = 23.5 - 1
			local ok, errors = OfficeKitRules.check(kit)
			expect(ok).to.equal(false)
			expect(hasError(errors, "wall trim")).to.equal(true)
			kit.markers[2].z = 23.5 - 1 - trim
			local clear, clearErrors = OfficeKitRules.check(kit)
			expect(clearErrors[1]).to.equal(nil)
			expect(clear).to.equal(true)
		end
	)

	it("holds a side-wall prop to the trim clearance on the footprint's yawed side", function()
		local trim = Constants.SHELL.trimClearance
		local kit = fixture()
		-- A planter (4.06 x 3.92) turned a quarter against the right wall's plaster face (29.5): 1.96 deep in X.
		table.insert(kit.markers, { kind = "prop", art = "planter", x = 29.5 - 1.96, z = 14, rotation = math.pi / 2 })
		local _, flush = OfficeKitRules.check(kit)
		expect(hasError(flush, "wall trim")).to.equal(true)
		kit.markers[#kit.markers].x = 29.5 - 1.96 - trim
		local ok, errors = OfficeKitRules.check(kit)
		expect(errors[1]).to.equal(nil)
		expect(ok).to.equal(true)
	end)

	it("flags a pile crowding furniture", function()
		local kit = fixture()
		kit.markers[3].x = 22
		kit.markers[3].z = 18
		local _, errors = OfficeKitRules.check(kit)
		expect(hasError(errors, "crowds")).to.equal(true)
	end)

	describe("prop markers", function()
		it("flags a wall prop hung over the door on the front wall, but not beside it", function()
			local kit = fixture()
			-- The front wall's inner face is at 0.5: a 0.27-deep frame, turned half way to face into the room.
			table.insert(kit.markers, { kind = "prop", art = "artFrame", x = 15, z = 0.635, rotation = math.pi })
			local ok, errors = OfficeKitRules.check(kit)
			expect(ok).to.equal(false)
			expect(hasError(errors, "hangs over the door")).to.equal(true)
			-- 4 wide: 20..24 clears the door's 12..18; 17.5..21.5 still overlaps its edge.
			kit.markers[#kit.markers].x = 22
			local clear, clearErrors = OfficeKitRules.check(kit)
			expect(clearErrors[1]).to.equal(nil)
			expect(clear).to.equal(true)
			kit.markers[#kit.markers].x = 19.5
			local _, edgeErrors = OfficeKitRules.check(kit)
			expect(hasError(edgeErrors, "hangs over the door")).to.equal(true)
		end)

		it("counts a floor prop as furniture: a sofa on a desk overlaps", function()
			local kit = fixture()
			table.insert(kit.markers, { kind = "prop", art = "sofa", x = 6, z = 8, rotation = 0 })
			local _, errors = OfficeKitRules.check(kit)
			expect(hasError(errors, "overlaps")).to.equal(true)
		end)

		it("keeps floor props out of the walls, the door approach and pile clearance", function()
			local kit = fixture()
			table.insert(kit.markers, { kind = "prop", art = "vending", x = 29, z = 12, rotation = 0 })
			table.insert(kit.markers, { kind = "prop", art = "copier", x = 15, z = 2.5, rotation = 0 })
			table.insert(kit.markers, { kind = "prop", art = "planter", x = 4, z = 18.5, rotation = 0 })
			local _, errors = OfficeKitRules.check(kit)
			expect(hasError(errors, "outside the walls")).to.equal(true)
			expect(hasError(errors, "door approach")).to.equal(true)
			expect(hasError(errors, "crowds")).to.equal(true)
		end)

		it("lets furniture and loot stand on a flat floor prop (a rug), but keeps it inside the walls", function()
			local kit = fixture()
			-- A 14 x 13 rug under the desk and its chair strip, reaching into the door approach, with a pile on it.
			table.insert(kit.markers, { kind = "prop", art = "rug", x = 12, z = 10, rotation = 0 })
			table.insert(kit.markers, { kind = "pile", x = 15, z = 12 })
			local ok, errors = OfficeKitRules.check(kit)
			expect(errors[1]).to.equal(nil)
			expect(ok).to.equal(true)
			-- The rug (the marker before the pile) moved to x 26 reaches 19..33, through the right wall (inner face 29.5).
			kit.markers[#kit.markers - 1].x = 26
			local _, outside = OfficeKitRules.check(kit)
			expect(hasError(outside, "prop 1 at (26, 10) is outside the walls")).to.equal(true)
		end)

		it("flags a prop with no art or an unsized one", function()
			local kit = fixture()
			table.insert(kit.markers, { kind = "prop", x = 20, z = 12 })
			table.insert(kit.markers, { kind = "prop", art = "nonsense", x = 22, z = 12 })
			local _, errors = OfficeKitRules.check(kit)
			expect(hasError(errors, "names no sized art")).to.equal(true)
		end)

		it("stands a window bay off the plaster by the trim clearance, so the trim runs behind it", function()
			local trim = Constants.SHELL.trimClearance
			local kit = fixture()
			-- 0.97 deep, flush on the back wall's plaster face (23.5): the wainscot and rail cross its lower part.
			table.insert(kit.markers, { kind = "prop", art = "windowBay", x = 22, z = 23.5 - 0.485, rotation = 0 })
			local _, flush = OfficeKitRules.check(kit)
			expect(hasError(flush, "wall trim")).to.equal(true)
			kit.markers[#kit.markers].z = 23.5 - 0.485 - trim
			local ok, errors = OfficeKitRules.check(kit)
			expect(errors[1]).to.equal(nil)
			expect(ok).to.equal(true)
		end)

		it("leaves a wall prop above the rail flat on the plaster", function()
			local kit = fixture()
			table.insert(kit.markers, { kind = "prop", art = "wallScreen", x = 22, z = 23.5 - 0.17, rotation = 0 })
			local ok, errors = OfficeKitRules.check(kit)
			expect(errors[1]).to.equal(nil)
			expect(ok).to.equal(true)
		end)

		it("lets a wall prop hang over floor furniture but only against a wall", function()
			local kit = fixture()
			-- The back wall's inner face is at 23.5: a 0.27-deep frame has its back there.
			table.insert(kit.markers, { kind = "prop", art = "artFrame", x = 22, z = 23.365, rotation = 0 })
			local ok, errors = OfficeKitRules.check(kit)
			expect(errors[1]).to.equal(nil)
			expect(ok).to.equal(true)
			table.insert(kit.markers, { kind = "prop", art = "wallClock", x = 15, z = 12, rotation = 0 })
			local _, loose = OfficeKitRules.check(kit)
			expect(hasError(loose, "not against a wall")).to.equal(true)
		end)
	end)

	it("uses the art's ART_SIZES footprint: a conferenceTable overlaps a desk the kind size would clear", function()
		local kit = fixture()
		table.insert(kit.markers, { kind = "table", x = 16, z = 12, rotation = 0 })
		local _, plainErrors = OfficeKitRules.check(kit)
		expect(hasError(plainErrors, "overlaps")).to.equal(false)
		kit.markers[#kit.markers].art = "conferenceTable"
		local ok, errors = OfficeKitRules.check(kit)
		expect(ok).to.equal(false)
		expect(hasError(errors, "desk 1 at (6, 8) overlaps table 1 at (16, 12)")).to.equal(true)
	end)

	it("keeps a restyled board's footprint inside the walls", function()
		local kit = fixture()
		table.insert(kit.markers, { kind = "board", x = 15, z = 23.3, rotation = 0 })
		local _, plain = OfficeKitRules.check(kit)
		expect(hasError(plain, "outside the walls")).to.equal(false)
		kit.markers[#kit.markers].art = "corkboard"
		local _, errors = OfficeKitRules.check(kit)
		expect(hasError(errors, "board 1 at (15, 23.3) is outside the walls")).to.equal(true)
	end)

	it("accepts a desk-top prop on a desk's centre and flags one off a desk", function()
		local kit = fixture()
		table.insert(kit.markers, { kind = "prop", art = "deskPlant", x = 6, z = 8, rotation = 0 })
		local ok = OfficeKitRules.check(kit)
		expect(ok).to.equal(true)
		kit.markers[#kit.markers].x = 14
		local _, errors = OfficeKitRules.check(kit)
		expect(hasError(errors, "is not on a desk")).to.equal(true)
	end)

	it("flags a desk-top prop whose yaw differs from its desk's", function()
		local kit = fixture()
		table.insert(kit.markers, { kind = "prop", art = "deskPlant", x = 6, z = 8, rotation = math.pi / 2 })
		local ok, errors = OfficeKitRules.check(kit)
		expect(ok).to.equal(false)
		expect(hasError(errors, "is not on a desk")).to.equal(true)
		kit.markers[#kit.markers].rotation = nil
		local fine = OfficeKitRules.check(kit)
		expect(fine).to.equal(true)
	end)
end
