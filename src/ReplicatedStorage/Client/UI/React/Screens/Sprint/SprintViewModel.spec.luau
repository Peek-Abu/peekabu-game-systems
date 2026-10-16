local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SprintViewModel = require(script.Parent.SprintViewModel)
local SprintConstants = require(ReplicatedStorage.Shared.Features.Sprint.Data.SprintConstants)

return function()
	it("hides a full bar", function()
		expect(SprintViewModel.bar(1, false)).to.equal(nil)
	end)

	it("shows a bar that is not full, low under the restart fraction", function()
		local view = SprintViewModel.bar(0.6, false)
		expect(view.fill).to.equal(0.6)
		expect(view.low).to.equal(false)
		expect(SprintViewModel.bar(SprintConstants.RESTART_FRACTION - 0.01, false).low).to.equal(true)
	end)

	it("hides while the HUD is hidden, and clamps a stray value", function()
		expect(SprintViewModel.bar(0.5, true)).to.equal(nil)
		expect(SprintViewModel.bar(-1, false).fill).to.equal(0)
		expect(SprintViewModel.bar(0 / 0, false)).to.equal(nil)
	end)
end
