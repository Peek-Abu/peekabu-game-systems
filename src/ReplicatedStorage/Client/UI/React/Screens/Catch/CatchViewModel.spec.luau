local CatchViewModel = require(script.Parent.CatchViewModel)

local REPORT = { room = "Archive", clock = 222, backAt = 108, dropped = { "Monitor", "Employee of the Month plaque" } }

local function snapshot(extra)
	local value = {
		phase = "running",
		sub = "normal",
		stage = "normal",
		tier = 0,
		shift = 1,
		endsAt = 352,
		quota = 350,
		cleared = 0,
		bonus = 0,
		quotaMet = false,
		variant = "B",
		votesAnother = 0,
		votesDepot = 0,
		crew = {},
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function input(extra)
	local value = {
		snapshot = snapshot(),
		me = { dead = true, caughtUntil = 106 },
		report = REPORT,
		targetName = "Sam",
		target = { carrying = "printer", room = "Server room", roomDepth = 2, cam = 6 },
		now = 100,
		prevKey = "←",
		nextKey = "→",
		phone = false,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("cctv", function()
		it("shows only while the local player is down in a running shift", function()
			expect(CatchViewModel.cctv(input({ me = { caughtUntil = 106 } }))).to.equal(nil)
			expect(CatchViewModel.cctv(input({ snapshot = snapshot({ phase = "results" }) }))).to.equal(nil)
			expect(CatchViewModel.cctv(input()) ~= nil).to.equal(true)
		end)

		it("labels the camera, the room and who is watched", function()
			local view = CatchViewModel.cctv(input())
			expect(view.rec).to.equal("REC   CAM 06 · SERVER ROOM")
			expect(view.watching).to.equal("WATCHING  SAM")
			expect(view.details).to.equal("carrying: Printer · 2 rooms from the truck")
		end)

		it("says one room, and the loading bay, in words", function()
			local near = CatchViewModel.cctv(input({ target = { roomDepth = 1, room = "Reception", cam = 2 } }))
			expect(near.details).to.equal("hands empty · 1 room from the truck")
			local bay = CatchViewModel.cctv(input({ target = { roomDepth = 0, room = "Loading bay", cam = 1 } }))
			expect(bay.details).to.equal("hands empty · at the truck")
		end)

		it("reads NO SIGNAL with nobody to watch", function()
			local value = input()
			value.targetName = nil
			value.target = nil
			local view = CatchViewModel.cctv(value)
			expect(view.watching).to.equal("NO SIGNAL")
			expect(view.rec).to.equal("REC   CAM -- · NO SIGNAL")
		end)

		it("counts down to the respawn and never below 0:00", function()
			expect(CatchViewModel.cctv(input()).back).to.equal("BACK ON THE CLOCK IN 0:06")
			expect(CatchViewModel.cctv(input({ now = 120 })).back).to.equal("BACK ON THE CLOCK IN 0:00")
		end)

		it("stamps a night clock from the time into the shift", function()
			-- endsAt 352, now 100: 252 s left of 420, so 168 s in: 03:02:48.
			expect(CatchViewModel.cctv(input()).stamp).to.equal("THU 03:02:48")
			expect(CatchViewModel.nightClock(3600)).to.equal("04:00:00")
		end)

		it("writes the incident report with the clock and the room", function()
			local view = CatchViewModel.cctv(input())
			expect(view.incidentTitle).to.equal("INCIDENT REPORT · YOU")
			expect(view.incident[1]).to.equal("Caught by Mr. Harlow at 3:42.")
			expect(view.incident[2]).to.equal("Your cargo dropped in the archive.")
		end)

		it("says nothing dropped for empty hands, and keeps the phone short", function()
			local empty = table.clone(REPORT)
			empty.dropped = {}
			expect(CatchViewModel.cctv(input({ report = empty })).incident[2]).to.equal("You were carrying nothing.")
			local phone = CatchViewModel.cctv(input({ phone = true }))
			expect(phone.incidentTitle).to.equal("INCIDENT REPORT")
			expect(phone.incident[1]).to.equal("Caught by Mr. Harlow.")
			expect(phone.details).to.equal("carrying: Printer")
		end)

		it("phrases a possessive room without 'the'", function()
			expect(CatchViewModel.roomPhrase("Mr. Harlow's office")).to.equal("Mr. Harlow's office")
			expect(CatchViewModel.roomPhrase("Break room")).to.equal("the break room")
		end)
	end)

	describe("rehired", function()
		local function rehiredInput(extra)
			local value = {
				report = REPORT,
				me = { dead = true, caughtUntil = 106 },
				name = "Ava",
				rehiredAt = nil,
				nowServer = 105,
				nowClock = 50,
				phone = false,
			}
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end

		it("shows from just before the respawn until a few seconds after it", function()
			expect(CatchViewModel.rehired(rehiredInput({ nowServer = 100 }))).to.equal(nil)
			expect(CatchViewModel.rehired(rehiredInput()) ~= nil).to.equal(true)
			local after = rehiredInput({ me = {}, rehiredAt = 49 })
			expect(CatchViewModel.rehired(after) ~= nil).to.equal(true)
			after.nowClock = 53
			expect(CatchViewModel.rehired(after)).to.equal(nil)
		end)

		it("needs a report", function()
			local value = rehiredInput()
			value.report = nil
			expect(CatchViewModel.rehired(value)).to.equal(nil)
		end)

		it("fills the HR notice", function()
			local view = CatchViewModel.rehired(rehiredInput())
			expect(view.title).to.equal("Rehired.")
			expect(view.rows[1]).to.equal("Name: Ava")
			expect(view.rows[2]).to.equal("Employment ended: 3:42 (caught by Mr. Harlow)")
			expect(view.rows[3]).to.equal("Re-hired: 3:34, no questions asked")
			expect(view.rows[4]).to.equal("Dropped: Monitor, Employee of the Month plaque. Go back for them!")
			expect(view.stamp).to.equal("REHIRED")
			expect(view.footer).to.equal("Respawning at the loading bay…")
		end)

		it("says nothing was dropped", function()
			local empty = table.clone(REPORT)
			empty.dropped = {}
			expect(CatchViewModel.rehired(rehiredInput({ report = empty })).rows[4]).to.equal("Dropped: nothing.")
		end)
	end)
end
