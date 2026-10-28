local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VM = require(script.Parent.CompanyTrackerViewModel)
local Rules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)

local MONDAY = 1792972800
local ORDER = { id = "piles8", kind = "piles", target = 8, label = "Help clear 8 piles" }

local function status(punched)
	return Rules.status({ week = MONDAY, punched = punched, weeks = 0 }, MONDAY + 3600)
end

return function()
	describe("where", function()
		local function input(overrides)
			local value = { pinned = true, clipboardOpen = false, inHub = true, hubBusy = false, inShift = false }
			for key, item in overrides or {} do
				value[key] = item
			end
			return value
		end

		it("shows in the hub and in a shift, pinned by default", function()
			expect(VM.where(input())).to.equal("hub")
			expect(VM.where(input({ inHub = false, inShift = true }))).to.equal("shift")
		end)

		it("hides when unpinned, under the open clipboard, or behind another hub screen", function()
			expect(VM.where(input({ pinned = false }))).to.equal(nil)
			expect(VM.where(input({ clipboardOpen = true }))).to.equal(nil)
			expect(VM.where(input({ hubBusy = true }))).to.equal(nil)
			expect(VM.where(input({ inHub = false }))).to.equal(nil)
		end)
	end)

	describe("lines", function()
		it("asks for today's punch in the hub, and points to the hub in a shift", function()
			local work = { day = 0, progress = 3, claimed = false }
			local hub = VM.lines("hub", status({}), work, ORDER, MONDAY + 3600)
			expect(hub.timecard).to.equal("PUNCH YOUR TIMECARD!")
			expect(hub.timecardDue).to.equal(true)
			expect(hub.order).to.equal("Help clear 8 piles")
			expect(hub.progress).to.equal(3)
			expect(hub.target).to.equal(8)
			expect(hub.footer).to.equal("+100 CREDITS")
			local shift = VM.lines("shift", status({}), work, ORDER, MONDAY + 3600)
			expect(shift.timecard).to.equal("PUNCH IN AT THE HUB!")
		end)

		it("counts the days once today is punched", function()
			local lines =
				VM.lines("hub", status({ 1 }), { day = 0, progress = 0, claimed = false }, ORDER, MONDAY + 3600)
			expect(lines.timecard).to.equal("TIMECARD: 1 / 5 DAYS")
			expect(lines.timecardDue).to.equal(false)
		end)

		it("says the card is full and counts down to tomorrow's order once today's is paid", function()
			local full = status({ 1, 2, 3, 4, 5 })
			-- 1 hour into the UTC day: 23h 0m to the next order.
			local lines = VM.lines("hub", full, { day = 0, progress = 8, claimed = true }, ORDER, MONDAY + 3600)
			expect(lines.order).to.equal("ALL DONE TODAY!")
			expect(lines.claimed).to.equal(true)
			expect(lines.footer).to.equal("NEW ORDER IN 23h 0m")
		end)
	end)
end
