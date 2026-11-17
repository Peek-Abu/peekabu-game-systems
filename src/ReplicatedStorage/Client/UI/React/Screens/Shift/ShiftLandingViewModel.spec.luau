local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftLandingViewModel = require(script.Parent.ShiftLandingViewModel)
local ShiftCrewViewModel = require(script.Parent.ShiftCrewViewModel)
local ShiftHudViewModel = require(script.Parent.ShiftHudViewModel)
local ShiftLandingFormulas = require(ReplicatedStorage.Client.Features.Shift.Utils.ShiftLandingFormulas)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

return function()
	describe("clock", function()
		it("writes night times on a 12-hour clock", function()
			expect(ShiftLandingViewModel.clock(23 * 60)).to.equal("11:00 PM")
			expect(ShiftLandingViewModel.clock(23 * 60 + 59)).to.equal("11:59 PM")
			expect(ShiftLandingViewModel.clock(0)).to.equal("12:00 AM")
			expect(ShiftLandingViewModel.clock(30)).to.equal("12:30 AM")
			expect(ShiftLandingViewModel.clock(60 + 12)).to.equal("1:12 AM")
			expect(ShiftLandingViewModel.clock(3 * 60 + 59)).to.equal("3:59 AM")
			expect(ShiftLandingViewModel.clock(12 * 60 + 5)).to.equal("12:05 PM")
		end)
	end)

	describe("card", function()
		it("lists temperature, time, weather, then danger, in that order", function()
			local view = ShiftLandingViewModel.card(42, "office")
			expect(view.heading).to.equal("TONIGHT")
			expect(#view.rows).to.equal(3)
			expect(view.rows[1].label).to.equal("Temp")
			expect(view.rows[2].label).to.equal("Time")
			expect(view.rows[3].label).to.equal("Weather")
			expect(view.danger).to.equal("Danger")
		end)

		it("draws the seed's night", function()
			local night = ShiftLandingFormulas.night(42)
			local view = ShiftLandingViewModel.card(42, "office")
			expect(view.rows[1].value).to.equal(`{night.temperature}°F`)
			expect(view.rows[2].value).to.equal(ShiftLandingViewModel.clock(night.minutes))
			expect(view.rows[3].value).to.equal(night.weather)
		end)

		it("is the same card for the same seed and map", function()
			local a = ShiftLandingViewModel.card(31337, "school")
			local b = ShiftLandingViewModel.card(31337, "school")
			for index, row in a.rows do
				expect(row.value).to.equal(b.rows[index].value)
			end
			expect(a.drops).to.equal(b.drops)
		end)

		it("shows the map's danger: Office one Gloom drop, School two", function()
			expect(DepotConstants.OFFICE_SITE.danger).to.equal(1)
			expect(DepotConstants.SCHOOL_SITE.danger).to.equal(2)
			expect(ShiftLandingViewModel.card(1, "office").drops).to.equal(1)
			expect(ShiftLandingViewModel.card(1, "school").drops).to.equal(2)
		end)

		it("reads an unknown map as the office", function()
			local view = ShiftLandingViewModel.card(1, nil)
			expect(view.drops).to.equal(1)
			expect(view.place).to.equal(DepotConstants.OFFICE_SITE.site)
		end)

		it("names the map's site under the heading", function()
			expect(ShiftLandingViewModel.card(1, "school").place).to.equal(DepotConstants.SCHOOL_SITE.site)
		end)
	end)

	describe("frame", function()
		it("sits on the desktop's left side under the crew list, above the hotbar", function()
			local viewport = Vector2.new(1920, 1080)
			local frame = ShiftLandingViewModel.frame("desktop", viewport)
			local size = ShiftLandingViewModel.SIZE.desktop
			expect(frame.X).to.equal(24)
			-- The crew list (66 px down) with six members ends near 342 px.
			local list = ShiftCrewViewModel.listSize(false, 6)
			expect(frame.Y >= 66 + list.Y).to.equal(true)
			expect(frame.Y + size.Y <= viewport.Y * 0.8).to.equal(true)
		end)

		it("sits on the phone's left side, left of the centred meter and above the thumbstick", function()
			for _, viewport in { Vector2.new(844, 390), Vector2.new(667, 320), Vector2.new(740, 360) } do
				local frame = ShiftLandingViewModel.frame("phone", viewport)
				local size = ShiftLandingViewModel.SIZE.phone
				expect(frame.X).to.equal(12)
				expect(frame.Y >= 40).to.equal(true)
				-- The centred meter's left edge, less its Gloom render breaking that edge.
				local meter = ShiftHudViewModel.METER.phone
				local meterLeft = viewport.X / 2 - ShiftCrewViewModel.phoneFit(viewport.X).meter / 2
				local meterEdge = meterLeft - meter.icon * ShiftHudViewModel.METER_ICON_OVERHANG
				expect(frame.X + size.X <= meterEdge).to.equal(true)
				expect(frame.Y + size.Y <= viewport.Y - ShiftCrewViewModel.PHONE_BAND.thumbTop).to.equal(true)
			end
		end)
	end)

	describe("slide", function()
		it("slides in from off the left edge and rests at the frame", function()
			local width = ShiftLandingViewModel.SIZE.desktop.X
			expect(ShiftLandingViewModel.slide(0, 24, width) <= -width).to.equal(true)
			expect(ShiftLandingViewModel.slide(1, 24, width)).to.equal(24)
			local mid = ShiftLandingViewModel.slide(0.5, 24, width)
			expect(mid > -width and mid < 24).to.equal(true)
		end)
	end)
end
