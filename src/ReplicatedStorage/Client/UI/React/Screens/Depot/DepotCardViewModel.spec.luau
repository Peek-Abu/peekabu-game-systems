local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotCardViewModel = require(script.Parent.DepotCardViewModel)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local function card(kind, client, truck)
	return {
		kind = kind,
		client = client or "Pemberton Dental",
		job = "4th floor offices. Harlow is in tonight.",
		note = "Watch the fish tank. Fragile!",
		quota = 350,
		truck = truck or 0,
		expiresAt = 10,
	}
end

return function()
	describe("drive", function()
		it("writes the dispatch ticket", function()
			local view = DepotCardViewModel.drive(card("drive", nil, 2))
			expect(view.band).to.equal("HARLOW & FINCH — DISPATCH")
			expect(view.truck).to.equal("TRUCK 2")
			expect(view.title).to.equal("ON THE ROAD")
			expect(view.heading).to.equal("Heading to Pemberton Dental")
			expect(view.seconds).to.equal(DepotConstants.DRIVE_CARD_SECONDS)
		end)

		it("leaves the truck off when it is unknown", function()
			expect(DepotCardViewModel.drive(card("drive", nil, 0)).truck).to.equal(nil)
		end)
	end)

	describe("arrival", function()
		it("writes the job folder", function()
			local view = DepotCardViewModel.arrival(card("arrival"))
			expect(view.tab).to.equal("ARRIVAL")
			expect(view.client).to.equal("Pemberton Dental")
			expect(view.job).to.equal("4th floor offices. Harlow is in tonight.")
			expect(view.slip).to.equal("CLEARANCE CONTRACT")
			expect(view.clear).to.equal("CLEAR 350")
			expect(view.before).to.equal(`of trash before {ShiftHudViewModel.clock(ShiftConstants.SHIFT_SECONDS)}`)
			expect(view.note).to.equal("Watch the fish tank. Fragile!")
		end)
	end)

	it("cuts a long client name on both cards", function()
		local long = string.rep("Pemberton ", 6)
		local drive = DepotCardViewModel.drive(card("drive", long, 1))
		local arrival = DepotCardViewModel.arrival(card("arrival", long, 1))
		expect(utf8.len(arrival.client)).to.equal(DepotCardViewModel.CLIENT_MAX)
		expect(string.sub(arrival.client, -3)).to.equal("…")
		expect(drive.heading).to.equal(`Heading to {arrival.client}`)
	end)
end
