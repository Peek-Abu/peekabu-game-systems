local DepotPadViewModel = require(script.Parent.DepotPadViewModel)
local ShiftQuotaFormulas = require(game:GetService("ReplicatedStorage").Shared.Features.Shift.Utils.ShiftQuotaFormulas)

local NAMES = { [1] = "Sam", [2] = "Alex", [3] = "Me" }

local function pad(extra)
	local value = { members = { 1, 2, 3 }, capacity = 4, destination = "shift", endsAt = 111, departing = false }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("maps", function()
		local function held(extra)
			local value = pad({ held = true, endsAt = nil })
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end

		it("gives the host both map cards to tap, the pick marked", function()
			local view = DepotPadViewModel.pad(held(), 3, NAMES, 2, 100, false, 3)
			local maps = DepotPadViewModel.maps(view, "school")
			expect(maps.canPick).to.equal(true)
			expect(maps.line).to.equal("Pick a map!")
			expect(#maps.cards).to.equal(2)
			expect(maps.cards[1].map).to.equal("office")
			expect(maps.cards[1].label).to.equal("OFFICE")
			expect(maps.cards[1].selected).to.equal(false)
			expect(maps.cards[2].map).to.equal("school")
			expect(maps.cards[2].label).to.equal("SCHOOL")
			expect(maps.cards[2].selected).to.equal(true)
		end)

		it("shows the rest of the crew the host's pick, not to tap", function()
			local view = DepotPadViewModel.pad(held(), 3, NAMES, 2, 100, false, 1)
			local maps = DepotPadViewModel.maps(view, "office")
			expect(maps.canPick).to.equal(false)
			expect(maps.line).to.equal("The host picks the map.")
			expect(maps.cards[1].selected).to.equal(true)
			expect(maps.cards[2].selected).to.equal(false)
		end)

		it("lets nobody pick before the server names a host", function()
			local view = DepotPadViewModel.pad(held(), 3, NAMES, 2, 100, false, nil)
			expect(DepotPadViewModel.maps(view, "office").canPick).to.equal(false)
		end)

		it("shows no cards off a hosted truck, once it is leaving, or when not aboard", function()
			expect(DepotPadViewModel.maps(nil, "office")).to.equal(nil)
			local plain = DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, false)
			expect(DepotPadViewModel.maps(plain, "office")).to.equal(nil)
			local leaving = DepotPadViewModel.pad(held({ departing = true }), 3, NAMES, 2, 100, false, 3)
			expect(DepotPadViewModel.maps(leaving, "office")).to.equal(nil)
		end)

		it("keeps the pick locked in while the countdown runs (the host may still change it)", function()
			local view = DepotPadViewModel.pad(held({ endsAt = 104 }), 3, NAMES, 2, 100, false, 3)
			local maps = DepotPadViewModel.maps(view, "school")
			expect(maps.canPick).to.equal(true)
			expect(maps.cards[2].selected).to.equal(true)
		end)
	end)

	it("shows nothing when not aboard", function()
		expect(DepotPadViewModel.pad(nil, 3, NAMES, 2, 100, false)).to.equal(nil)
		expect(DepotPadViewModel.pad(pad({ members = { 1 } }), 3, NAMES, 2, 100, false)).to.equal(nil)
	end)

	it("titles the card with the truck, the job and this crew's quota", function()
		local three = ShiftQuotaFormulas.quota(3)
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, false).title).to.equal(
			`TRUCK 2 — HARLOW & FINCH JOB · {three} GLOOM`
		)
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, nil, 100, false).title).to.equal(
			`HARLOW & FINCH JOB · {three} GLOOM`
		)
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, true).title).to.equal(`TRUCK 2 · CREW · {three} GLOOM`)
	end)

	it("follows the crew aboard: a solo truck posts the solo quota", function()
		local view = DepotPadViewModel.pad(pad({ members = { 3 } }), 3, NAMES, 1, 100, true)
		expect(view.title).to.equal(`TRUCK 1 · CREW · {ShiftQuotaFormulas.quota(1)} GLOOM`)
	end)

	it("counts the crew and fills open slots up to capacity, you marked", function()
		local view = DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, false)
		expect(view.count).to.equal("3 / 4")
		expect(#view.slots).to.equal(4)
		expect(view.slots[3].name).to.equal("you")
		expect(view.slots[3].you).to.equal(true)
		expect(view.slots[4].open).to.equal(true)
		expect(view.slots[4].name).to.equal("open")
	end)

	it("calls a member with no name Crew", function()
		local view = DepotPadViewModel.pad(pad({ members = { 1, 9, 3 } }), 3, NAMES, 2, 100, true)
		expect(view.slots[2].name).to.equal("Crew")
		expect(view.names).to.equal("Sam · Crew · you")
	end)

	it("lists names for the phone", function()
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, true).names).to.equal("Sam · Alex · you")
	end)

	it("counts down to departure, never below 0:00", function()
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, false).departsIn).to.equal("0:11")
		expect(DepotPadViewModel.pad(pad({ endsAt = 90 }), 3, NAMES, 2, 100, false).departsIn).to.equal("0:00")
	end)

	it("drops the countdown while departing", function()
		local view = DepotPadViewModel.pad(pad({ endsAt = nil, departing = true }), 3, NAMES, 2, 100, false)
		expect(view.departing).to.equal(true)
		expect(view.departsIn).to.equal(nil)
	end)

	it("writes the leave hint per layout", function()
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, false).hint).to.equal(
			"Step off the bed to leave · timer resets when someone joins"
		)
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, true).hint).to.equal("Step off the truck bed to leave")
	end)
	describe("shown", function()
		it("shows on a truck bed in the depot hub", function()
			expect(DepotPadViewModel.shown(nil, 3, false, nil)).to.equal(true)
			expect(DepotPadViewModel.shown({ phase = "lobby", crew = { 3 } }, 3, false, nil)).to.equal(true)
			expect(DepotPadViewModel.shown({ phase = "running", crew = { 1 } }, 3, false, "arrival")).to.equal(true)
		end)
		it("closes once the crew departs (the drive card is up)", function()
			expect(DepotPadViewModel.shown(nil, 3, false, "drive")).to.equal(false)
		end)
		it("stays hidden behind the load screen", function()
			expect(DepotPadViewModel.shown(nil, 3, true, nil)).to.equal(false)
		end)
		it("stays hidden for a crew member during the shift and its results", function()
			for _, phase in { "starting", "running", "results" } do
				expect(DepotPadViewModel.shown({ phase = phase, crew = { 1, 3 } }, 3, false, nil)).to.equal(false)
			end
		end)
	end)

	describe("the Next shift card", function()
		it("invites a player who is not aboard to find a truck", function()
			local cta = DepotPadViewModel.cta(nil, nil)
			expect(cta.title).to.equal("NEXT SHIFT")
			expect(cta.aboard).to.equal(false)
			expect(cta.time).to.equal(nil)
			expect(cta.go).to.equal("GO!")
			expect(#cta.seats).to.equal(0)
		end)

		it("counts down the truck's departure with a seat per place, you and the crew by id", function()
			local view = DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, false)
			local cta = DepotPadViewModel.cta(view, 2)
			expect(cta.aboard).to.equal(true)
			expect(cta.line).to.equal("Truck 2 departs in")
			expect(cta.time).to.equal(view.departsIn)
			expect(#cta.seats).to.equal(4)
			expect(cta.seats[1].userId).to.equal(1)
			expect(cta.seats[3].you).to.equal(true)
			expect(cta.seats[4].open).to.equal(true)
			expect(cta.canGo).to.equal(true)
		end)

		it("stops offering GO once the truck is leaving", function()
			local view = DepotPadViewModel.pad(pad({ departing = true }), 3, NAMES, 2, 100, false)
			local cta = DepotPadViewModel.cta(view, 2)
			expect(cta.canGo).to.equal(false)
			expect(cta.time).to.equal(nil)
			expect(cta.line).to.equal("Truck 2 is leaving!")
		end)

		it("departs now on an unhosted truck and opens the jobs board off a truck", function()
			expect(DepotPadViewModel.cta(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, false), 2).action).to.equal(
				"depart"
			)
			expect(DepotPadViewModel.cta(nil, nil).action).to.equal("jobs")
		end)
	end)

	describe("a hosted truck", function()
		-- A hosted truck nobody has started: no countdown (a nil in the overrides table would not clear it).
		local function unstarted()
			local value = pad({ held = true })
			value.endsAt = nil
			return value
		end

		it("offers the host START and crowns their seat", function()
			local view = DepotPadViewModel.pad(unstarted(), 3, NAMES, 2, 100, false, 3)
			local cta = DepotPadViewModel.cta(view, 2)
			expect(cta.line).to.equal("You're the host!")
			expect(cta.go).to.equal("START")
			expect(cta.action).to.equal("start")
			expect(cta.variant).to.equal("primary")
			expect(cta.canGo).to.equal(true)
			expect(cta.seats[3].host).to.equal(true)
			expect(cta.seats[1].host).to.equal(false)
		end)

		it("offers the host CANCEL while the countdown runs", function()
			local view = DepotPadViewModel.pad(pad({ held = true, endsAt = 104 }), 3, NAMES, 2, 100, false, 3)
			local cta = DepotPadViewModel.cta(view, 2)
			expect(cta.line).to.equal("Truck 2 departs in")
			expect(cta.time).to.equal(view.departsIn)
			expect(cta.go).to.equal("CANCEL")
			expect(cta.action).to.equal("cancel")
		end)

		it("tells a rider who they wait for and offers LEAVE", function()
			local view = DepotPadViewModel.pad(unstarted(), 3, NAMES, 2, 100, false, 1)
			local cta = DepotPadViewModel.cta(view, 2)
			expect(cta.line).to.equal("Waiting for Sam to start")
			expect(cta.go).to.equal("LEAVE")
			expect(cta.action).to.equal("leave")
			expect(cta.variant).to.equal("secondary")
			expect(cta.seats[1].host).to.equal(true)
		end)

		it("shows a rider the countdown once the host starts", function()
			local view = DepotPadViewModel.pad(pad({ held = true, endsAt = 104 }), 3, NAMES, 2, 100, false, 1)
			local cta = DepotPadViewModel.cta(view, 2)
			expect(cta.line).to.equal("Truck 2 departs in")
			expect(cta.go).to.equal("LEAVE")
		end)

		it("names an unknown host plainly", function()
			local view = DepotPadViewModel.pad(unstarted(), 3, NAMES, 2, 100, false, 9)
			expect(DepotPadViewModel.cta(view, 2).line).to.equal("Waiting for the host to start")
		end)

		it("gives the host the lock and lets them pick another crew member to kick", function()
			local view = DepotPadViewModel.pad(unstarted(), 3, NAMES, 2, 100, false, 3, true)
			local cta = DepotPadViewModel.cta(view, 2)
			expect(cta.hostControls.locked).to.equal(true)
			expect(cta.seats[1].kickable).to.equal(true)
			expect(cta.seats[3].kickable).to.equal(false) -- themself
			expect(cta.seats[4].kickable).to.equal(false) -- an open seat
		end)

		it("offers a host without the Big Crew pass the upgrade, once the pass exists", function()
			local view = DepotPadViewModel.pad(unstarted(), 3, NAMES, 2, 100, false, 3, false)
			expect(DepotPadViewModel.cta(view, 2, true).hostControls.upgrade).to.equal(true)
			expect(DepotPadViewModel.cta(view, 2, false).hostControls.upgrade).to.equal(false)
			expect(DepotPadViewModel.cta(view, 2).hostControls.upgrade).to.equal(false)
		end)

		it("draws a seat per live seat: six on a Big Crew truck", function()
			local big = unstarted()
			big.capacity = 6
			local view = DepotPadViewModel.pad(big, 3, NAMES, 2, 100, false, 3, false)
			expect(view.count).to.equal("3 / 6")
			expect(#DepotPadViewModel.cta(view, 2).seats).to.equal(6)
		end)

		it("gives a rider no host controls and nobody to kick", function()
			local view = DepotPadViewModel.pad(unstarted(), 3, NAMES, 2, 100, false, 1, false)
			local cta = DepotPadViewModel.cta(view, 2)
			expect(cta.hostControls).to.equal(nil)
			for _, seat in cta.seats do
				expect(seat.kickable).to.equal(false)
			end
		end)

		it("offers nothing once the truck is leaving", function()
			local view = DepotPadViewModel.pad(pad({ held = true, departing = true }), 3, NAMES, 2, 100, false, 3)
			local cta = DepotPadViewModel.cta(view, 2)
			expect(cta.canGo).to.equal(false)
			expect(cta.line).to.equal("Truck 2 is leaving!")
			expect(cta.hostControls).to.equal(nil)
			expect(cta.seats[1].kickable).to.equal(false)
		end)
	end)
end
