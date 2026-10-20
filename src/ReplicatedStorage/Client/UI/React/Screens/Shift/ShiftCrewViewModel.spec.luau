local ShiftCrewViewModel = require(script.Parent.ShiftCrewViewModel)
local ShiftHudViewModel = require(script.Parent.ShiftHudViewModel)

local NAMES = { [1] = "Sam", [2] = "Alex", [3] = "Jo" }

local function players(map)
	local result = {}
	for userId, entry in map do
		result[tostring(userId)] = entry
	end
	return result
end

local function statusOf(view, userId)
	for _, member in view.members do
		if member.userId == userId then
			return member
		end
	end
	return nil
end

return function()
	it("shows nothing for an empty crew", function()
		expect(ShiftCrewViewModel.roster({}, {}, NAMES, nil, false, 0)).to.equal(nil)
	end)

	it("titles the card with the truck when known", function()
		expect(ShiftCrewViewModel.roster({ 1 }, players({}), NAMES, 2, false, 0).title).to.equal(
			"CREW ROSTER · TRUCK 2"
		)
		expect(ShiftCrewViewModel.roster({ 1 }, players({}), NAMES, nil, false, 0).title).to.equal("CREW ROSTER")
	end)

	it("reads carrying, vacuuming, at the truck and the room in that order", function()
		local view = ShiftCrewViewModel.roster(
			{ 1, 2, 3 },
			players({
				[1] = { carrying = "coffeeMachine", vacuuming = true },
				[2] = { vacuuming = true, inTruck = true },
				[3] = { inTruck = true, room = "Loading bay" },
			}),
			NAMES,
			2,
			false,
			0
		)
		expect(statusOf(view, 1).status).to.equal("carrying Coffee machine")
		expect(statusOf(view, 1).tone).to.equal("busy")
		expect(statusOf(view, 2).status).to.equal("vacuuming")
		expect(statusOf(view, 2).tone).to.equal("ok")
		expect(statusOf(view, 3).status).to.equal("at the truck")
	end)

	it("puts CAUGHT above every other status", function()
		local view = ShiftCrewViewModel.roster(
			{ 2 },
			players({
				[2] = { caughtUntil = 106, carrying = "coffeeMachine", dead = true },
			}),
			NAMES,
			nil,
			false,
			100
		)
		local alex = statusOf(view, 2)
		expect(alex.status).to.equal("CAUGHT · back 0:06")
		expect(alex.tone).to.equal("danger")
		expect(alex.struck).to.equal(true)
		-- The time the countdown runs to, so the detail line can tick on its own.
		expect(alex.caughtUntil).to.equal(106)
	end)

	it("carries no countdown for a member who is not caught", function()
		local view =
			ShiftCrewViewModel.roster({ 2 }, players({ [2] = { carrying = "coffeeMachine" } }), NAMES, nil, false, 100)
		expect(statusOf(view, 2).caughtUntil).to.equal(nil)
	end)

	it("clamps the back-in countdown at 0:00", function()
		local view = ShiftCrewViewModel.roster(
			{ 2 },
			players({ [2] = { caughtUntil = 90, dead = true } }),
			NAMES,
			nil,
			false,
			100
		)
		expect(statusOf(view, 2).status).to.equal("CAUGHT · back 0:00")
	end)

	it("shows a punched card as clocked out even before the truck's countdown", function()
		local view = ShiftCrewViewModel.roster(
			{ 1, 3 },
			players({ [3] = { vacuuming = true } }),
			NAMES,
			nil,
			false,
			0,
			{ 1 }
		)
		expect(statusOf(view, 1).status).to.equal("clocked out")
		expect(statusOf(view, 1).box).to.equal("tick")
		expect(statusOf(view, 3).status).to.equal("vacuuming")
	end)

	it("shows clocked out / still inside only while the truck counts down, never struck", function()
		local crew = players({ [1] = { inTruck = true, carrying = "coffeeMachine" }, [3] = { vacuuming = true } })
		local out = ShiftCrewViewModel.roster({ 1, 3 }, crew, NAMES, 2, true, 0, { 1 })
		expect(statusOf(out, 1).status).to.equal("clocked out")
		expect(statusOf(out, 1).tone).to.equal("ok")
		expect(statusOf(out, 3).status).to.equal("still inside")
		expect(statusOf(out, 3).struck).to.equal(false)
		local normal = ShiftCrewViewModel.roster({ 1, 3 }, crew, NAMES, 2, false, 0)
		expect(statusOf(normal, 1).status).to.equal("carrying Coffee machine")
		expect(statusOf(normal, 3).status).to.equal("vacuuming")
	end)

	it("keeps CAUGHT above clocked out / still inside while clocking out", function()
		local view = ShiftCrewViewModel.roster(
			{ 2 },
			players({
				[2] = { caughtUntil = 106, dead = true, inTruck = true },
			}),
			NAMES,
			nil,
			true,
			100
		)
		local alex = statusOf(view, 2)
		expect(alex.status).to.equal("CAUGHT · back 0:06")
		expect(alex.tone).to.equal("danger")
		expect(alex.struck).to.equal(true)
	end)

	it("reads a dead player with no back-in time as plain CAUGHT", function()
		local view = ShiftCrewViewModel.roster({ 2 }, players({ [2] = { dead = true } }), NAMES, nil, false, 100)
		local alex = statusOf(view, 2)
		expect(alex.status).to.equal("CAUGHT")
		expect(alex.tone).to.equal("danger")
		expect(alex.struck).to.equal(true)
	end)

	it("ticks only crew who clocked out or are at the truck", function()
		local crew = players({
			[1] = { carrying = "coffeeMachine", inTruck = true },
			[2] = { caughtUntil = 106, dead = true },
			[3] = { vacuuming = true },
		})
		local normal = ShiftCrewViewModel.roster({ 1, 2, 3 }, crew, NAMES, nil, false, 100)
		expect(statusOf(normal, 1).box).to.equal("empty")
		expect(statusOf(normal, 2).box).to.equal("x")
		expect(statusOf(normal, 3).box).to.equal("empty")
		local atTruck = ShiftCrewViewModel.roster({ 1 }, players({ [1] = { inTruck = true } }), NAMES, nil, false, 0)
		expect(statusOf(atTruck, 1).box).to.equal("tick")
		local room = ShiftCrewViewModel.roster({ 1 }, players({ [1] = { room = "Archive" } }), NAMES, nil, false, 0)
		expect(statusOf(room, 1).box).to.equal("empty")
		local out = ShiftCrewViewModel.roster({ 1, 3 }, crew, NAMES, nil, true, 100, { 1 })
		expect(statusOf(out, 1).box).to.equal("tick")
		expect(statusOf(out, 3).box).to.equal("empty")
	end)

	it("falls back to the room, then to on shift", function()
		local view = ShiftCrewViewModel.roster({ 1, 2 }, players({ [1] = { room = "Archive" } }), NAMES, nil, false, 0)
		expect(statusOf(view, 1).status).to.equal("Archive")
		expect(statusOf(view, 1).tone).to.equal("muted")
		expect(statusOf(view, 2).status).to.equal("on shift")
	end)

	it("writes the phone's two lines, trouble on the second", function()
		local view = ShiftCrewViewModel.roster(
			{ 1, 2, 3 },
			players({
				[1] = { carrying = "coffeeMachine" },
				[2] = { caughtUntil = 106, dead = true },
				[3] = { vacuuming = true },
			}),
			NAMES,
			nil,
			false,
			100
		)
		expect(view.compact[1]).to.equal("Sam: carrying · Jo: vacuuming")
		expect(view.compact[2]).to.equal("Alex: CAUGHT · back 0:06")
	end)

	it("groups names that share a status on the phone", function()
		local view = ShiftCrewViewModel.roster(
			{ 1, 2, 3 },
			players({
				[1] = { inTruck = true },
				[2] = { inTruck = true },
			}),
			NAMES,
			nil,
			true,
			0,
			{ 1, 2 }
		)
		expect(view.compact[1]).to.equal("Sam, Alex: clocked out · Jo: still inside")
	end)

	it("marks which phone line is trouble, even when it is the only line", function()
		local mixed = ShiftCrewViewModel.roster(
			{ 1, 2 },
			players({ [1] = { carrying = "coffeeMachine" }, [2] = { caughtUntil = 106, dead = true } }),
			NAMES,
			nil,
			false,
			100
		)
		expect(mixed.compactDanger[1]).to.equal(false)
		expect(mixed.compactDanger[2]).to.equal(true)
		local allCaught = ShiftCrewViewModel.roster(
			{ 2 },
			players({ [2] = { caughtUntil = 106, dead = true } }),
			NAMES,
			nil,
			false,
			100
		)
		expect(#allCaught.compact).to.equal(1)
		expect(allCaught.compactDanger[1]).to.equal(true)
	end)

	it("names an unknown player Crew", function()
		local view = ShiftCrewViewModel.roster({ 9 }, players({}), NAMES, nil, false, 0)
		expect(view.members[1].name).to.equal("Crew")
	end)

	describe("listSize", function()
		it("is the card's width and its padded rows, 2 px apart", function()
			expect(ShiftCrewViewModel.listSize(false, 3)).to.equal(Vector2.new(236, 24 + 3 * 42))
			expect(ShiftCrewViewModel.listSize(true, 4)).to.equal(Vector2.new(176, 16 + 4 * 30))
			expect(ShiftCrewViewModel.listSize(true, 4, 151)).to.equal(Vector2.new(151, 16 + 4 * 30))
		end)
	end)

	describe("phoneFit", function()
		it("keeps the full meter and list on a 844 phone", function()
			local fit = ShiftCrewViewModel.phoneFit(844)
			expect(fit.meter).to.equal(400)
			expect(fit.list).to.equal(176)
		end)

		it("narrows both on a 667 phone so the meter's stopwatch ends clear of the list", function()
			local fit = ShiftCrewViewModel.phoneFit(667)
			expect(fit.list).to.equal(151)
			expect(fit.meter).to.equal(667 - 64 - 2 * 151)
			local stopwatchEdge = 667 / 2 + fit.meter / 2 + 16
			local listLeft = 667 - 10 - fit.list
			expect(listLeft - stopwatchEdge >= 6).to.equal(true)
		end)

		it("never lets the meter and the list overlap from 656 px up, and never goes under the minimums", function()
			for width = 656, 960 do
				local fit = ShiftCrewViewModel.phoneFit(width)
				expect(width - 10 - fit.list - (width / 2 + fit.meter / 2 + 16) >= 6).to.equal(true)
				expect(fit.list >= 140 and fit.meter >= 300).to.equal(true)
			end
		end)
	end)

	describe("detailLine", function()
		-- A stand-in measure: 10 px a character.
		local function widthOf(text)
			return utf8.len(text) * 10
		end

		it("keeps the whole line when it fits", function()
			expect(ShiftCrewViewModel.detailLine("Sam", "vacuuming", 200, widthOf)).to.equal("Sam: vacuuming")
		end)

		it("cuts a long name short with an ellipsis, as little as it must, and never the status", function()
			-- "Alexandria: CAUGHT · back 0:12" is 30 characters; 25 fit.
			expect(ShiftCrewViewModel.detailLine("Alexandria", "CAUGHT · back 0:12", 250, widthOf)).to.equal(
				"Alex…: CAUGHT · back 0:12"
			)
		end)

		it("falls back to the initial alone, and cuts by character, not by byte", function()
			expect(ShiftCrewViewModel.detailLine("Alexandria", "CAUGHT · back 0:12", 210, widthOf)).to.equal(
				"A: CAUGHT · back 0:12"
			)
			expect(ShiftCrewViewModel.detailLine("Zoë Ångström", "CAUGHT", 150, widthOf)).to.equal(
				"Zoë Ån…: CAUGHT"
			)
		end)
	end)

	describe("rosterFrame", function()
		local METER = ShiftHudViewModel.METER
		local OVERHANG = ShiftHudViewModel.METER_ICON_OVERHANG

		-- Whether two rects (top-left, size) share any area.
		local function overlaps(aAt, aSize, bAt, bSize)
			return aAt.X < bAt.X + bSize.X
				and bAt.X < aAt.X + aSize.X
				and aAt.Y < bAt.Y + bSize.Y
				and bAt.Y < aAt.Y + aSize.Y
		end

		-- The meter plate with its Gloom render and its stopwatch render (they break its left and top-right edges).
		local function meterRect(phone, viewport)
			local meter = if phone then METER.phone else METER.desktop
			local plate = if phone then ShiftCrewViewModel.phoneFit(viewport.X).meter else meter.size.X
			local left = viewport.X / 2 - plate / 2 - meter.icon * OVERHANG
			local right = viewport.X / 2 + plate / 2 + (if phone then 16 else 22)
			local top = meter.top - (if phone then 24 else 34)
			return Vector2.new(left, top), Vector2.new(right - left, meter.top + meter.size.Y + 7 - top)
		end

		it("opens beside the crew list on a wide desktop window, clear of the meter", function()
			local viewport = Vector2.new(1920, 1080)
			local frame = ShiftCrewViewModel.rosterFrame(false, viewport, 3, Vector2.new(24, 66))
			expect(frame.position).to.equal(Vector2.new(24 + 236 + 12, 66))
			expect(frame.size).to.equal(Vector2.new(300, 20 + 4 * 28))
			expect(frame.line).to.equal(28)
			local at, size = meterRect(false, viewport)
			expect(overlaps(frame.position, frame.size, at, size)).to.equal(false)
		end)

		it(
			"drops under the crew list when the meter's Gloom render would reach it (1366x768 at 0.75, or at 1)",
			function()
				for _, viewport in
					{ Vector2.new(1366 / 0.75, 768 / 0.75), Vector2.new(1366, 768), Vector2.new(1000, 700) }
				do
					local frame = ShiftCrewViewModel.rosterFrame(false, viewport, 3, Vector2.new(24, 66))
					expect(frame.position).to.equal(Vector2.new(24, 66 + 24 + 3 * 42 + 12))
					local at, size = meterRect(false, viewport)
					expect(overlaps(frame.position, frame.size, at, size)).to.equal(false)
				end
			end
		)

		-- Everything else on a phone screen the open roster must stay clear of (top-left corner, size).
		local function phoneObstacles(viewport, count)
			local w, h = viewport.X, viewport.Y
			local meterAt, meterSize = meterRect(true, viewport)
			local obstacles = {
				meter = { meterAt, meterSize },
				list = {
					Vector2.new(w - 10 - ShiftCrewViewModel.phoneFit(w).list, 6),
					ShiftCrewViewModel.listSize(true, count, ShiftCrewViewModel.phoneFit(w).list),
				},
				-- ShiftClockOutBoard: 330x80 centred at 114 (+7 drop), its tilted clock render reaching 29 px left.
				board = { Vector2.new(w / 2 - 165 - 29, 114 - 7), Vector2.new(330 + 29, 80 + 7 + 7) },
				-- ShiftPromptChip: 250x54 centred at 236.
				chip = { Vector2.new(w / 2 - 125, 236), Vector2.new(250, 54) },
				-- The thumbstick's resting ring: the bottom 150 px of the left 40%.
				thumb = { Vector2.new(0, h - 150), Vector2.new(w * 0.4, 150) },
				-- Roblox's top-left menu and chat buttons, over the top bar.
				topBar = { Vector2.new(0, 0), Vector2.new(140, 58) },
			}
			local arc = ShiftHudViewModel.arcFor(math.min(w, h))
			for name, spot in arc do
				obstacles[`arc_{name}`] = { Vector2.new(w + spot.x, h + spot.y), Vector2.new(spot.size, spot.size) }
			end
			return obstacles
		end

		local function expectClear(frame, viewport, count)
			for name, rect in phoneObstacles(viewport, count) do
				local gap = if name == "thumb" or name == "board" then 8 else 0
				local at = rect[1] - Vector2.new(gap, gap)
				local size = rect[2] + Vector2.new(2 * gap, 2 * gap)
				if overlaps(frame.position, frame.size, at, size) then
					error(`the roster ({count} members on {viewport}) overlaps the {name}`)
				end
			end
		end

		it("opens on the left under the meter on a 844x390 phone, clear of the board and the rest", function()
			local viewport = Vector2.new(844, 390)
			for count = 1, 4 do
				local frame = ShiftCrewViewModel.rosterFrame(true, viewport, count, Vector2.new(658, 6))
				expect(frame.position).to.equal(Vector2.new(10, 28 + 70 + 8))
				-- Up to the board's clock render (422 - 165 - 29 = 228) less the 8 px gap.
				expect(frame.size).to.equal(Vector2.new(210, 20 + (count + 1) * 20))
				expect(frame.line).to.equal(20)
				expect(frame.padding).to.equal(8)
				expectClear(frame, viewport, count)
			end
		end)

		it("keeps the meter and the top-right crew list apart on 667 and 844 phones, up to 4 members", function()
			for _, viewport in { Vector2.new(667, 375), Vector2.new(844, 390) } do
				for count = 1, 4 do
					local obstacles = phoneObstacles(viewport, count)
					local meter, list = obstacles.meter, obstacles.list
					expect(overlaps(meter[1], meter[2], list[1], list[2])).to.equal(false)
				end
			end
		end)

		it("narrows on a 667x375 phone and tightens its lines so 4 members still end above the thumbstick", function()
			local viewport = Vector2.new(667, 375)
			for count = 1, 4 do
				local frame = ShiftCrewViewModel.rosterFrame(true, viewport, count, Vector2.new(481, 6))
				expect(frame.position).to.equal(Vector2.new(10, 106))
				expect(frame.size.X).to.equal(121)
				expect(frame.line).to.equal(if count == 4 then 18 else 20)
				expectClear(frame, viewport, count)
			end
		end)
	end)
end
