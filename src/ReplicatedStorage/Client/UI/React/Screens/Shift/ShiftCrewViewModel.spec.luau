local ShiftCrewViewModel = require(script.Parent.ShiftCrewViewModel)

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
end
