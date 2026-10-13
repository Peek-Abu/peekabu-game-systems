local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotBoardViewModel = require(script.Parent.DepotBoardViewModel)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

local LAST = {
	cleared = 362,
	quota = 350,
	bonus = 215,
	catches = 2,
	salvage = 6,
	offered = 9,
	quotaMet = true,
	rating = "satisfactory",
	truck = 2,
}

local function rowOf(view, label)
	for _, row in view.rows do
		if row.label == label then
			return row
		end
	end
	return nil
end

return function()
	it("numbers the work order the same way every time", function()
		expect(DepotBoardViewModel.workOrder("harlow-finch-1")).to.equal("#2802")
		expect(DepotBoardViewModel.workOrder("harlow-finch-2")).to.equal("#2803")
	end)

	it("heads the work order with the client and the site", function()
		local contract = DepotConstants.CONTRACTS[1]
		local view = DepotBoardViewModel.board(contract.id, nil, false)
		expect(view.title).to.equal("TONIGHT'S JOB")
		expect(view.workOrder).to.equal("WORK ORDER #2802")
		expect(view.headline).to.equal(`{string.upper(contract.client)} — 4TH FLOOR OFFICES`)
		expect(view.subline).to.equal(contract.job)
	end)

	it("lists the desktop rows with the hazard marked and the contract's note", function()
		local contract = DepotConstants.CONTRACTS[2]
		local view = DepotBoardViewModel.board(contract.id, nil, false)
		expect(#view.rows).to.equal(6)
		expect(rowOf(view, "QUOTA").text).to.equal("350 clearance (rubbish bags, dust bags, recycling)")
		expect(rowOf(view, "SHIFT").text).to.equal("7:00 on the clock. Clock out at the truck any time.")
		expect(rowOf(view, "HAZARD").hazard).to.equal(true)
		expect(rowOf(view, "QUOTA").hazard).to.equal(false)
		expect(rowOf(view, "NOTES").text).to.equal(contract.note)
	end)

	it("keeps the phone to four short rows", function()
		local view = DepotBoardViewModel.board(nil, nil, true)
		expect(#view.rows).to.equal(4)
		expect(rowOf(view, "QUOTA").text).to.equal("350 clearance")
		expect(rowOf(view, "PAY").text).to.equal(`Assets → {ShiftConstants.CURRENCY_NAME}`)
	end)

	it("reads the first contract when none is open", function()
		expect(DepotBoardViewModel.board(nil, nil, false).subline).to.equal(DepotConstants.CONTRACTS[1].job)
	end)

	it("shows no last-shift card for a player who has not played", function()
		expect(DepotBoardViewModel.board(nil, nil, false).last).to.equal(nil)
	end)

	it("fills the last-shift card", function()
		local last = DepotBoardViewModel.board(nil, LAST, false).last
		expect(last.title).to.equal("YOUR LAST SHIFT — TRUCK 2")
		expect(last.rows[1].value).to.equal("362 / 350")
		expect(last.rows[2].value).to.equal("+215")
		expect(last.rows[3].value).to.equal("2")
		expect(last.rows[4].value).to.equal("6 of 9")
		expect(last.stamp).to.equal("QUOTA MET")
	end)

	it("drops the truck from the title when unknown and stamps a missed quota", function()
		local missed = table.clone(LAST)
		missed.truck = 0
		missed.quotaMet = false
		local last = DepotBoardViewModel.board(nil, missed, false).last
		expect(last.title).to.equal("YOUR LAST SHIFT")
		expect(last.stamp).to.equal("QUOTA MISSED")
		expect(last.met).to.equal(false)
	end)

	it("writes the phone's two last-shift lines", function()
		local last = DepotBoardViewModel.board(nil, LAST, true).last
		expect(last.title).to.equal("LAST SHIFT")
		expect(last.lines[1]).to.equal(`Cleared 362/350  ·  +215 {ShiftConstants.CURRENCY_NAME}`)
		expect(last.lines[2]).to.equal("Rehired 2  ·  Assets 6 of 9")
	end)

	describe("fit", function()
		it("draws the board at full size when the screen has room", function()
			expect(DepotBoardViewModel.fit(Vector2.new(1920, 1080), false)).to.equal(1)
			expect(DepotBoardViewModel.fit(Vector2.new(2560, 1440), false)).to.equal(1)
			expect(DepotBoardViewModel.fit(Vector2.new(844, 390), true)).to.equal(1)
		end)

		it("shrinks the desktop board to the narrower side of a small screen", function()
			-- 1366 - 120 = 1246 across of 1580; 768 - 136 = 632 down of 900 (the tighter one).
			expect(DepotBoardViewModel.fit(Vector2.new(1366, 768), false)).to.be.near(632 / 900, 1e-6)
		end)

		it("shrinks the phone board on a short phone", function()
			-- 667 - 96 = 571 across of 748; 375 - 82 = 293 down of 308.
			expect(DepotBoardViewModel.fit(Vector2.new(667, 375), true)).to.be.near(571 / 748, 1e-6)
		end)

		it("never draws below a floor on a tiny or empty viewport", function()
			expect(DepotBoardViewModel.fit(Vector2.new(0, 0), false)).to.equal(DepotBoardViewModel.MIN_SCALE)
		end)
	end)
end
