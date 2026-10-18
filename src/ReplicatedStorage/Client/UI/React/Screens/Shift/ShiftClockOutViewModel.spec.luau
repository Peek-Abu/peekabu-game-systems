local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftClockOutViewModel = require(script.Parent.ShiftClockOutViewModel)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

local function snapshot(overrides)
	local base = {
		phase = "running",
		sub = "normal",
		stage = "normal",
		tier = 0,
		shift = 1,
		endsAt = 520,
		quota = 350,
		cleared = 0,
		bonus = 0,
		quotaMet = false,
		variant = "B",
		votesAnother = 0,
		votesDepot = 0,
		crew = { 1, 2, 3, 4 },
		punched = {},
		crewIn = 4,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	describe("board", function()
		it("is hidden until someone clocks out, and outside a run", function()
			expect(ShiftClockOutViewModel.board(snapshot(), 1)).to.equal(nil)
			expect(ShiftClockOutViewModel.board(nil, 1)).to.equal(nil)
			expect(ShiftClockOutViewModel.board(snapshot({ phase = "results", punched = { 1 } }), 1)).to.equal(nil)
		end)

		it("counts who clocked out of the crew still in, before the truck's countdown", function()
			local view = ShiftClockOutViewModel.board(snapshot({ punched = { 2 } }), 1)
			expect(view.tally).to.equal("1/4 CLOCKED OUT")
			expect(view.leavesAt).to.equal(nil)
			expect(view.headline).to.equal("CLOCKING OUT")
			expect(view.mine).to.equal(false)
			expect(view.selected).to.equal(nil)
			expect(#view.cards).to.equal(4)
			expect(view.cards[1]).to.equal(true)
			expect(view.cards[2]).to.equal(false)
		end)

		it("shows the truck's countdown once it runs", function()
			local view =
				ShiftClockOutViewModel.board(snapshot({ punched = { 1, 2 }, sub = "clockout", clockOutAt = 130 }), 3)
			expect(view.tally).to.equal("2/4 CLOCKED OUT")
			expect(view.leavesAt).to.equal(130)
			expect(view.headline).to.equal("TRUCK LEAVES IN")
			expect(view.hint).to.equal("Clock out at the truck to ride along")
		end)

		it("tells a punched player they are on the truck, their card first", function()
			local view = ShiftClockOutViewModel.board(snapshot({ punched = { 2 }, crewIn = 2 }), 2)
			expect(view.mine).to.equal(true)
			expect(view.selected).to.equal(1)
			expect(view.hint).to.equal("You're on the truck")
			expect(view.tally).to.equal("1/2 CLOCKED OUT")
		end)

		it("leaves a member who quit the game out of the count", function()
			local view = ShiftClockOutViewModel.board(snapshot({ crew = { 1, 2 }, punched = { 2, 7 }, crewIn = 2 }), 1)
			expect(view.tally).to.equal("1/2 CLOCKED OUT")
		end)

		it("never draws fewer cards than punches", function()
			local view = ShiftClockOutViewModel.board(snapshot({ punched = { 1, 2 }, crewIn = 0 }), 1)
			expect(#view.cards).to.equal(2)
		end)
	end)

	describe("urgent", function()
		it("turns urgent for the countdown's ticking seconds", function()
			expect(ShiftClockOutViewModel.urgent(ShiftConstants.COUNTDOWN_TICKS)).to.equal(true)
			expect(ShiftClockOutViewModel.urgent(ShiftConstants.COUNTDOWN_TICKS + 1)).to.equal(false)
		end)
	end)
end
