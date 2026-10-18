local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PaperToastViewModel = require(script.Parent.PaperToastViewModel)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

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
	end)
end
