--!strict
--[=[
	Unit tests for ReplicationViewCheck (R5 spec §1.2): each check, its allowance, episode start / end, and the
	two review-focus cases (a reason change restarts the allowance; a rejoin gets a fresh first-seen time).
]=]

local ReplicationViewCheck = require(script.Parent.ReplicationViewCheck)

return function()
	local tripwire

	-- A healthy view: player 2 in slot 4, visible, held, dressed, placed, Character correct.
	local function healthy()
		return {
			otherUserIds = { 2 },
			knownUserIds = { [2] = true },
			bodies = {
				{
					slot = 4,
					userId = 2,
					generation = 1,
					epoch = 3,
					held = true,
					placed = true,
					dressed = true,
					bufferEmpty = false,
					playerPresent = true,
				},
			},
			held = { { slot = 4, ownerUserId = 2 } },
			characters = { { userId = 2, matches = true } },
		}
	end

	beforeEach(function()
		tripwire = ReplicationViewCheck.new()
	end)

	it("a healthy view opens nothing", function()
		local started, ended = ReplicationViewCheck.check(tripwire, healthy(), 0)
		expect(#started).to.equal(0)
		expect(#ended).to.equal(0)
		started = ReplicationViewCheck.check(tripwire, healthy(), 10)
		expect(#started).to.equal(0)
	end)

	it("missing (not placed) opens after 0.5 s, not before, and ends when placed", function()
		local view = healthy()
		view.bodies[1].placed = false
		expect(#ReplicationViewCheck.check(tripwire, view, 0)).to.equal(0)
		expect(#ReplicationViewCheck.check(tripwire, view, 0.4)).to.equal(0)
		local started = ReplicationViewCheck.check(tripwire, view, 0.5)
		expect(#started).to.equal(1)
		expect(started[1].check).to.equal("missing")
		expect(started[1].reason).to.equal("notPlaced")
		local _, ended = ReplicationViewCheck.check(tripwire, healthy(), 1.2)
		expect(#ended).to.equal(1)
		expect(ended[1].endedAt).to.equal(1.2)
		expect(ReplicationViewCheck.getState(tripwire).counts.missing).to.equal(1)
	end)

	it("an undressed puppet is allowed 1.5 s, an empty buffer 2 s, a missing Player 3 s", function()
		local undressed = healthy()
		undressed.bodies[1].dressed = false
		undressed.bodies[1].placed = false
		ReplicationViewCheck.check(tripwire, undressed, 0)
		expect(#ReplicationViewCheck.check(tripwire, undressed, 1.4)).to.equal(0)
		expect(#ReplicationViewCheck.check(tripwire, undressed, 1.5)).to.equal(1)

		tripwire = ReplicationViewCheck.new()
		local empty = healthy()
		empty.bodies[1].bufferEmpty = true
		empty.bodies[1].placed = false
		ReplicationViewCheck.check(tripwire, empty, 0)
		expect(#ReplicationViewCheck.check(tripwire, empty, 1.9)).to.equal(0)
		expect(#ReplicationViewCheck.check(tripwire, empty, 2)).to.equal(1)

		tripwire = ReplicationViewCheck.new()
		local noPlayer = healthy()
		noPlayer.bodies[1].playerPresent = false
		noPlayer.bodies[1].held = false
		noPlayer.held = {}
		ReplicationViewCheck.check(tripwire, noPlayer, 0)
		expect(#ReplicationViewCheck.check(tripwire, noPlayer, 2.9)).to.equal(0)
		expect(#ReplicationViewCheck.check(tripwire, noPlayer, 3)).to.equal(1)
	end)

	-- A reason change restarts the allowance for the new reason.
	it("a reason change restarts the allowance for the new reason", function()
		local noPlayer = healthy()
		noPlayer.bodies[1].playerPresent = false
		noPlayer.bodies[1].held = false
		noPlayer.held = {}
		ReplicationViewCheck.check(tripwire, noPlayer, 0)
		ReplicationViewCheck.check(tripwire, noPlayer, 2.5)
		local undressed = healthy()
		undressed.bodies[1].dressed = false
		undressed.bodies[1].placed = false
		expect(#ReplicationViewCheck.check(tripwire, undressed, 2.6)).to.equal(0) -- not 2.6 s "undressed"
		expect(#ReplicationViewCheck.check(tripwire, undressed, 4.0)).to.equal(0)
		-- 4.2, not 4.1: 4.1 - 2.6 is 1.4999… in floating point.
		local started = ReplicationViewCheck.check(tripwire, undressed, 4.2)
		expect(#started).to.equal(1)
		expect(started[1].reason).to.equal("undressed")
	end)

	it("unknownPlayer counts from first seen and ends when the slot entry arrives", function()
		local view = healthy()
		view.otherUserIds = { 2, 7 }
		ReplicationViewCheck.check(tripwire, view, 0)
		expect(#ReplicationViewCheck.check(tripwire, view, 2.9)).to.equal(0)
		local started = ReplicationViewCheck.check(tripwire, view, 3)
		expect(#started).to.equal(1)
		expect(started[1].check).to.equal("unknownPlayer")
		view.knownUserIds[7] = true
		local _, ended = ReplicationViewCheck.check(tripwire, view, 4)
		expect(#ended).to.equal(1)
	end)

	-- A rejoin gets a fresh first-seen time.
	it("a player who leaves and rejoins gets a fresh first-seen time", function()
		local view = healthy()
		view.otherUserIds = { 2, 7 }
		ReplicationViewCheck.check(tripwire, view, 0)
		ReplicationViewCheck.check(tripwire, healthy(), 2) -- 7 left
		ReplicationViewCheck.check(tripwire, view, 10) -- 7 is back, still no entry
		expect(#ReplicationViewCheck.check(tripwire, view, 12.9)).to.equal(0)
		expect(#ReplicationViewCheck.check(tripwire, view, 13)).to.equal(1)
	end)

	it("orphan: a held puppet with no visible body, or the wrong owner", function()
		local noBody = healthy()
		noBody.held = { { slot = 4, ownerUserId = 2 }, { slot = 9, ownerUserId = 5 } }
		ReplicationViewCheck.check(tripwire, noBody, 0)
		local started = ReplicationViewCheck.check(tripwire, noBody, 0.5)
		expect(#started).to.equal(1)
		expect(started[1].check).to.equal("orphan")
		expect(started[1].reason).to.equal("noBody")

		tripwire = ReplicationViewCheck.new()
		local wrongOwner = healthy()
		wrongOwner.held = { { slot = 4, ownerUserId = 5 } }
		ReplicationViewCheck.check(tripwire, wrongOwner, 0)
		started = ReplicationViewCheck.check(tripwire, wrongOwner, 0.5)
		expect(#started).to.equal(1)
		expect(started[1].reason).to.equal("ownerMismatch")
	end)

	it("duplicate opens at once", function()
		local view = healthy()
		view.bodies[2] = {
			slot = 6,
			userId = 2,
			generation = 1,
			epoch = 3,
			held = true,
			placed = true,
			dressed = true,
			bufferEmpty = false,
			playerPresent = true,
		}
		view.held = { { slot = 4, ownerUserId = 2 }, { slot = 6, ownerUserId = 2 } }
		local started = ReplicationViewCheck.check(tripwire, view, 0)
		local checks = {}
		for _, episode in started do
			checks[episode.check] = true
		end
		expect(checks.duplicate).to.equal(true)
	end)

	it("characterMismatch opens after 0.5 s", function()
		local view = healthy()
		view.characters = { { userId = 2, matches = false } }
		ReplicationViewCheck.check(tripwire, view, 0)
		local started = ReplicationViewCheck.check(tripwire, view, 0.5)
		expect(#started).to.equal(1)
		expect(started[1].check).to.equal("characterMismatch")
	end)

	it("getState lists open episodes and describe names the reason and the duration", function()
		local view = healthy()
		view.bodies[1].placed = false
		ReplicationViewCheck.check(tripwire, view, 0)
		local started = ReplicationViewCheck.check(tripwire, view, 1)
		local state = ReplicationViewCheck.getState(tripwire)
		expect(state.checks).to.equal(2)
		expect(#state.open).to.equal(1)
		local _, ended = ReplicationViewCheck.check(tripwire, healthy(), 3)
		expect(string.find(ReplicationViewCheck.describe(started[1]), "notPlaced", 1, true) ~= nil).to.equal(true)
		expect(string.find(ReplicationViewCheck.describe(ended[1]), "3.0 s", 1, true) ~= nil).to.equal(true)
	end)
end
