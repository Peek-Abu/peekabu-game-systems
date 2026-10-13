local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotWorldViewModel = require(script.Parent.DepotWorldViewModel)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local NOW = 1000

-- A queue pad snapshot: `left` seconds on its countdown (nil: no countdown), optionally departing.
local function pad(members, left, departing)
	return {
		members = members,
		capacity = 4,
		destination = "shift",
		endsAt = if left ~= nil then NOW + left else nil,
		departing = departing == true,
	}
end

-- The public player map, from userId -> truck number.
local function players(trucks)
	local map = {}
	for userId, truck in trucks do
		map[tostring(userId)] = { [DepotConstants.PUBLIC_TRUCK] = truck }
	end
	return map
end

return function()
	describe("truckTag", function()
		it("shows an empty truck with open seats and how to join", function()
			local tag = DepotWorldViewModel.truckTag(1, 4, nil, NOW)
			expect(tag.title).to.equal("TRUCK 1")
			expect(#tag.seats).to.equal(4)
			for _, filled in tag.seats do
				expect(filled).to.equal(false)
			end
			expect(tag.count).to.equal("0 / 4 ABOARD")
			expect(tag.line).to.equal("Stand in the bed to join")
			expect(tag.warn).to.equal(false)
		end)

		it("fills a seat per player aboard and keeps the join line while time is left", function()
			local tag = DepotWorldViewModel.truckTag(2, 4, pad({ 11, 12 }, 15), NOW)
			expect(tag.seats[1]).to.equal(true)
			expect(tag.seats[2]).to.equal(true)
			expect(tag.seats[3]).to.equal(false)
			expect(tag.seats[4]).to.equal(false)
			expect(tag.count).to.equal("2 / 4 ABOARD")
			expect(tag.line).to.equal("Stand in the bed to join")
			expect(tag.warn).to.equal(false)
		end)

		it("counts down in red when the truck is full", function()
			local tag = DepotWorldViewModel.truckTag(3, 4, pad({ 1, 2, 3, 4 }, 30), NOW)
			expect(tag.count).to.equal("4 / 4 ABOARD")
			expect(tag.line).to.equal("Leaving in 0:30")
			expect(tag.warn).to.equal(true)
		end)

		it("counts down in red once TAG_WARN_SECONDS or fewer remain", function()
			local warn = DepotConstants.TAG_WARN_SECONDS
			local at = DepotWorldViewModel.truckTag(1, 4, pad({ 1 }, warn), NOW)
			expect(at.line).to.equal(`Leaving in 0:{string.format("%02d", warn)}`)
			expect(at.warn).to.equal(true)
			local before = DepotWorldViewModel.truckTag(1, 4, pad({ 1 }, warn + 0.5), NOW)
			expect(before.line).to.equal("Stand in the bed to join")
			expect(before.warn).to.equal(false)
		end)

		it("says the truck is leaving while it departs", function()
			local tag = DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, nil, true), NOW)
			expect(tag.line).to.equal("Leaving now")
			expect(tag.warn).to.equal(true)
		end)

		it("never counts below 0:00", function()
			local tag = DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2, 3, 4 }, -3), NOW)
			expect(tag.line).to.equal("Leaving in 0:00")
		end)
	end)

	describe("padFor", function()
		it("finds the pad whose crew stand in the truck", function()
			local snapshot = { pads = { a = pad({ 11 }, 10), b = pad({ 21, 22 }, 12) } }
			local found = DepotWorldViewModel.padFor(snapshot, 2, players({ [11] = 1, [21] = 2, [22] = 2 }))
			expect(found).to.equal(snapshot.pads.b)
		end)

		it("finds nothing for an empty truck, no snapshot, or crew without a truck field", function()
			local snapshot = { pads = { a = pad({ 11 }, 10) } }
			expect(DepotWorldViewModel.padFor(snapshot, 3, players({ [11] = 1 }))).to.equal(nil)
			expect(DepotWorldViewModel.padFor(nil, 1, players({ [11] = 1 }))).to.equal(nil)
			expect(DepotWorldViewModel.padFor(snapshot, 1, {})).to.equal(nil)
		end)
	end)

	describe("sameTag", function()
		it("is the same tag only when every drawn line matches", function()
			local a = DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, 9), NOW)
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, 9), NOW))).to.equal(
				true
			)
			-- 0.2 s later the clock still reads 0:09: nothing to re-render.
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, 9), NOW + 0.2))).to.equal(
				true
			)
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2 }, 8), NOW))).to.equal(
				false
			)
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(2, 4, pad({ 1, 2, 3 }, 9), NOW))).to.equal(
				false
			)
			expect(DepotWorldViewModel.sameTag(a, DepotWorldViewModel.truckTag(1, 4, pad({ 1, 2 }, 9), NOW))).to.equal(
				false
			)
			expect(DepotWorldViewModel.sameTag(nil, a)).to.equal(false)
			expect(DepotWorldViewModel.sameTag(a, nil)).to.equal(false)
			expect(DepotWorldViewModel.sameTag(nil, nil)).to.equal(true)
		end)
	end)

	describe("workOrder", function()
		local keys = DepotConstants.CONTRACT_KEYS

		local function board(client)
			return {
				[keys.id] = "harlow-finch-1",
				[keys.client] = client or "Harlow & Finch Ltd.",
				[keys.job] = "Clear the office before the sale.",
			}
		end

		it("reads tonight's contract off the board's attributes", function()
			local view = DepotWorldViewModel.workOrder(board())
			expect(view.number).to.equal(`WORK ORDER {DepotBoardViewModel.workOrder("harlow-finch-1")}`)
			expect(view.kicker).to.equal("TONIGHT'S JOB")
			expect(view.client).to.equal("Harlow & Finch Ltd.")
			expect(view.job).to.equal("Clear the office before the sale.")
			expect(view.clear).to.equal(`CLEAR {ShiftConstants.QUOTA}`)
			expect(view.before).to.equal(
				`of site buildup before {ShiftHudViewModel.clock(ShiftConstants.SHIFT_SECONDS)}`
			)
			expect(view.key).to.equal("E")
			expect(view.action).to.equal("Read the work order")
		end)

		it("cuts a long client name", function()
			local view = DepotWorldViewModel.workOrder(board(string.rep("Pemberton ", 6)))
			expect(utf8.len(view.client)).to.equal(DepotWorldViewModel.WORK_CLIENT_MAX)
			expect(string.sub(view.client, -3)).to.equal("…")
		end)

		it("draws nothing for a board without its contract", function()
			expect(DepotWorldViewModel.workOrder({})).to.equal(nil)
			local bad = board()
			bad[keys.client] = 5
			expect(DepotWorldViewModel.workOrder(bad)).to.equal(nil)
		end)
	end)

	describe("review", function()
		local keys = DepotConstants.REVIEW_KEYS
		local quotes = ShiftConstants.REVIEW_QUOTES

		local function card()
			return {
				[keys.client] = "Pemberton Dental",
				[keys.cleared] = 362,
				[keys.quota] = 350,
				[keys.bonus] = 215,
				[keys.catches] = 3,
				[keys.salvage] = 5,
				[keys.offered] = 9,
				[keys.met] = true,
				[keys.rating] = "exceeds",
				[keys.truck] = 2,
				[`{keys.crew}1`] = "Sam",
				[`{keys.crew}2`] = "Alex",
				[`{keys.crew}3`] = "Jo",
				[`{keys.awardTitle}1`] = "EMPLOYEE OF THE NIGHT",
				[`{keys.awardName}1`] = "Sam",
				[`{keys.awardTitle}2`] = "BUTTERFINGERS",
				[`{keys.awardName}2`] = "Jo",
			}
		end

		it("lays the card out like the review", function()
			local view = DepotWorldViewModel.review(card())
			expect(view.band).to.equal("SHIFT REVIEW · PEMBERTON DENTAL")
			expect(view.rows[1].label).to.equal("CLEARED")
			expect(view.rows[1].value).to.equal("362 / 350")
			expect(view.rows[2].label).to.equal(`{string.upper(ShiftConstants.CURRENCY_NAME)} EARNED`)
			expect(view.rows[2].value).to.equal("+215")
			expect(view.rows[3].label).to.equal("TIMES CAUGHT")
			expect(view.rows[3].value).to.equal("3")
			expect(view.rows[4].label).to.equal("ASSETS")
			expect(view.rows[4].value).to.equal("5 of 9")
			expect(view.headline).to.equal("QUOTA MET")
			expect(view.met).to.equal(true)
			expect(view.rating).to.equal("EXCEEDS EXPECTATIONS")
			expect(view.crew).to.equal("Crew: Sam · Alex · Jo")
			expect(view.quote).to.equal(`{quotes.met.line} {quotes.met.by}`)
			expect(#view.stickies).to.equal(2)
			expect(view.stickies[1].title).to.equal("EMPLOYEE OF THE NIGHT")
			expect(view.stickies[1].name).to.equal("Sam")
			expect(view.stickies[2].title).to.equal("BUTTERFINGERS")
			expect(view.stickies[2].name).to.equal("Jo")
		end)

		it("stamps a missed quota and never rates it above NEEDS IMPROVEMENT", function()
			local missed = card()
			missed[keys.met] = false
			local view = DepotWorldViewModel.review(missed)
			expect(view.headline).to.equal("QUOTA MISSED")
			expect(view.met).to.equal(false)
			expect(view.rating).to.equal("NEEDS IMPROVEMENT")
			expect(view.quote).to.equal(`{quotes.missed.line} {quotes.missed.by}`)
		end)

		it("reads an unknown rating as NEEDS IMPROVEMENT", function()
			local odd = card()
			odd[keys.rating] = "legendary"
			expect(DepotWorldViewModel.review(odd).rating).to.equal("NEEDS IMPROVEMENT")
		end)

		it("cuts a long client name in the band", function()
			local long = card()
			long[keys.client] = string.rep("Pemberton ", 6)
			local view = DepotWorldViewModel.review(long)
			local clipped = string.sub(view.band, #"SHIFT REVIEW · " + 1)
			expect(utf8.len(clipped)).to.equal(DepotWorldViewModel.BAND_CLIENT_MAX)
			expect(string.sub(clipped, -3)).to.equal("…")
		end)

		it("lists at most four crew and three awards, stopping at the first gap", function()
			local many = card()
			many[`{keys.crew}4`] = "Kim"
			many[`{keys.crew}5`] = "Extra"
			many[`{keys.awardTitle}3`] = "QUIETEST FEET"
			many[`{keys.awardName}3`] = "Alex"
			many[`{keys.awardTitle}4`] = "LOUDEST VACUUM"
			many[`{keys.awardName}4`] = "Kim"
			local view = DepotWorldViewModel.review(many)
			expect(view.crew).to.equal("Crew: Sam · Alex · Jo · Kim")
			expect(#view.stickies).to.equal(3)
			local gap = card()
			gap[`{keys.crew}2`] = nil
			expect(DepotWorldViewModel.review(gap).crew).to.equal("Crew: Sam")
		end)

		it("cuts each crew name", function()
			local long = card()
			long[`{keys.crew}1`] = string.rep("A", 40)
			local view = DepotWorldViewModel.review(long)
			local first = string.match(view.crew, "^Crew: (.-) · ")
			expect(utf8.len(first)).to.equal(DepotWorldViewModel.CREW_NAME_MAX)
			expect(string.sub(first, -3)).to.equal("…")
			expect(view.crew).to.equal(`Crew: {first} · Alex · Jo`)
		end)

		it("draws no card from attributes that are not a card", function()
			expect(DepotWorldViewModel.review({})).to.equal(nil)
			local bad = card()
			bad[keys.met] = "yes"
			expect(DepotWorldViewModel.review(bad)).to.equal(nil)
			local noCount = card()
			noCount[keys.cleared] = "lots"
			expect(DepotWorldViewModel.review(noCount)).to.equal(nil)
		end)
	end)

	describe("drawsSharedBoard", function()
		it("draws the shared result board only while this client has no review shell", function()
			expect(DepotWorldViewModel.drawsSharedBoard(false)).to.equal(true)
			expect(DepotWorldViewModel.drawsSharedBoard(true)).to.equal(false)
		end)
	end)
end
