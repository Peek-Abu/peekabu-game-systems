local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantPaViewModel = require(script.Parent.OccupantPaViewModel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

return function()
	it("draws nothing without a notice or a line", function()
		expect(OccupantPaViewModel.view(nil)).to.equal(nil)
		expect(OccupantPaViewModel.view({ line = "", callout = false, untilTime = 1 })).to.equal(nil)
	end)

	it("heads a corporate line for all staff, in ink", function()
		local view =
			OccupantPaViewModel.view({ line = "The Manager will see you now.", callout = false, untilTime = 1 })
		expect(view.band).to.equal(OccupantPaViewModel.BAND)
		expect(view.bandColor).to.equal(UIPaperConstants.COLOR.ink)
		expect(view.text).to.equal("The Manager will see you now.")
	end)

	it("stamps a call-out red", function()
		local view = OccupantPaViewModel.view({ line = "Pippa. My office.", callout = true, untilTime = 1 })
		expect(view.band).to.equal(OccupantPaViewModel.CALLOUT_BAND)
		expect(view.bandColor).to.equal(UIPaperConstants.COLOR.stamp)
	end)

	it("cuts a long line", function()
		local long = string.rep("a", OccupantPaViewModel.LINE_MAX + 10)
		local view = OccupantPaViewModel.view({ line = long, callout = false, untilTime = 1 })
		expect(utf8.len(view.text)).to.equal(OccupantPaViewModel.LINE_MAX)
	end)
end
