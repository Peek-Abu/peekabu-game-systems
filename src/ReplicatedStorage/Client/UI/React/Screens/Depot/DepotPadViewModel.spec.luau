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
	it("shows nothing when not aboard", function()
		expect(DepotPadViewModel.pad(nil, 3, NAMES, 2, 100, false)).to.equal(nil)
		expect(DepotPadViewModel.pad(pad({ members = { 1 } }), 3, NAMES, 2, 100, false)).to.equal(nil)
	end)

	it("titles the card with the truck, the job and this crew's quota", function()
		local three = ShiftQuotaFormulas.quota(3)
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, false).title).to.equal(
			`TRUCK 2 — HARLOW & FINCH JOB · QUOTA {three}`
		)
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, nil, 100, false).title).to.equal(
			`HARLOW & FINCH JOB · QUOTA {three}`
		)
		expect(DepotPadViewModel.pad(pad(), 3, NAMES, 2, 100, true).title).to.equal(`TRUCK 2 · CREW · QUOTA {three}`)
	end)

	it("follows the crew aboard: a solo truck posts the solo quota", function()
		local view = DepotPadViewModel.pad(pad({ members = { 3 } }), 3, NAMES, 1, 100, true)
		expect(view.title).to.equal(`TRUCK 1 · CREW · QUOTA {ShiftQuotaFormulas.quota(1)}`)
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
end
