local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PaperToastViewModel = require(script.Parent.PaperToastViewModel)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local UIPaperConstants = require(script.Parent.UIPaperConstants)

local function toast(id, style, text)
	return { id = id, text = text or `toast {id}`, style = style or ShiftConstants.TOAST_STICKY, expiresAt = 100 }
end

return function()
	it("splits stamps from notes", function()
		local view = PaperToastViewModel.layout(
			{ toast(1), toast(2, ShiftConstants.TOAST_STAMP, "QUOTA MET"), toast(3, "info") },
			3
		)
		expect(view.stamp.text).to.equal("QUOTA MET")
		expect(#view.notes).to.equal(2)
	end)

	it("puts the newest note first and keeps at most the limit", function()
		local view = PaperToastViewModel.layout({ toast(1), toast(2), toast(3), toast(4) }, 3)
		expect(#view.notes).to.equal(3)
		expect(view.notes[1].id).to.equal(4)
		expect(view.notes[3].id).to.equal(2)
	end)

	it("shows only the newest stamp", function()
		local view = PaperToastViewModel.layout({
			toast(1, ShiftConstants.TOAST_STAMP, "OVERTIME"),
			toast(2, ShiftConstants.TOAST_STAMP, "QUOTA MET"),
		}, 3)
		expect(view.stamp.text).to.equal("QUOTA MET")
	end)

	it("tilts notes alternately by id, so a note keeps its tilt as others come and go", function()
		local view = PaperToastViewModel.layout({ toast(7), toast(8) }, 3)
		expect(view.notes[1].tilt).to.equal(-view.notes[2].tilt)
		expect(PaperToastViewModel.layout({ toast(8) }, 3).notes[1].tilt).to.equal(view.notes[1].tilt)
	end)

	it("is empty for no toasts", function()
		local view = PaperToastViewModel.layout({}, 3)
		expect(view.stamp).to.equal(nil)
		expect(#view.notes).to.equal(0)
		expect(#view.slips).to.equal(0)
	end)

	describe("slips", function()
		it("keeps slip toasts out of the notes and the stamp", function()
			local view = PaperToastViewModel.layout({
				toast(1),
				toast(2, ShiftConstants.TOAST_SLIP, "Monitor\n36 Gleam"),
				toast(3, ShiftConstants.TOAST_STAMP, "QUOTA MET"),
			}, 3)
			expect(#view.notes).to.equal(1)
			expect(view.stamp.text).to.equal("QUOTA MET")
			expect(#view.slips).to.equal(1)
			expect(view.slips[1].title).to.equal("Monitor")
			expect(view.slips[1].detail).to.equal("36 Gleam")
			expect(view.slips[1].jackpot).to.equal(false)
		end)

		it("reads a one-line slip as its title alone", function()
			local view = PaperToastViewModel.layout({ toast(5, ShiftConstants.TOAST_SLIP, "Monitor") }, 3)
			expect(view.slips[1].title).to.equal("Monitor")
			expect(view.slips[1].detail).to.equal(nil)
		end)

		it("marks a jackpot slip", function()
			local view =
				PaperToastViewModel.layout({ toast(4, ShiftConstants.TOAST_SLIP_JACKPOT, "Gold-trim monitor") }, 3)
			expect(view.slips[1].jackpot).to.equal(true)
		end)

		it("stacks slips newest first, at most the slip limit, without using the note limit", function()
			local toasts = {}
			for id = 1, 5 do
				table.insert(toasts, toast(id, ShiftConstants.TOAST_SLIP))
			end
			table.insert(toasts, toast(6))
			local view = PaperToastViewModel.layout(toasts, 1, 2)
			expect(#view.slips).to.equal(2)
			expect(view.slips[1].id).to.equal(5)
			expect(view.slips[2].id).to.equal(4)
			expect(#view.notes).to.equal(1)
		end)

		it("defaults to MAX_SLIPS", function()
			local toasts = {}
			for id = 1, PaperToastViewModel.MAX_SLIPS + 2 do
				table.insert(toasts, toast(id, ShiftConstants.TOAST_SLIP))
			end
			expect(#PaperToastViewModel.layout(toasts, 3).slips).to.equal(PaperToastViewModel.MAX_SLIPS)
		end)

		it("tilts slips a little, alternately by id", function()
			local view = PaperToastViewModel.layout(
				{ toast(7, ShiftConstants.TOAST_SLIP), toast(8, ShiftConstants.TOAST_SLIP) },
				3
			)
			expect(view.slips[1].tilt).to.equal(-view.slips[2].tilt)
			expect(math.abs(view.slips[1].tilt) <= math.abs(UIPaperConstants.STICKY_TILT)).to.equal(true)
		end)
	end)
end
