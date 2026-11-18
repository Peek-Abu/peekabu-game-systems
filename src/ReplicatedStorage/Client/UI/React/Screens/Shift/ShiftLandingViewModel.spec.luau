local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftLandingViewModel = require(script.Parent.ShiftLandingViewModel)
local ShiftCrewViewModel = require(script.Parent.ShiftCrewViewModel)
local ShiftHudViewModel = require(script.Parent.ShiftHudViewModel)
local ShiftLandingFormulas = require(ReplicatedStorage.Client.Features.Shift.Utils.ShiftLandingFormulas)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local PaperHudScaleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudScaleViewModel)

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

	describe("screens", function()
		it("is three screens: temperature and weather, then the time, then the anomaly level", function()
			local night = ShiftLandingFormulas.night(42)
			local screens = ShiftLandingViewModel.screens(42, "office")
			expect(#screens).to.equal(3)
			expect(#screens[1].lines).to.equal(2)
			expect(screens[1].lines[1].text).to.equal(`{night.temperature}°F`)
			expect(screens[1].lines[1].icon).to.equal("temperature")
			expect(screens[1].lines[2].text).to.equal(string.upper(night.weather))
			expect(screens[1].lines[2].icon).to.equal(ShiftLandingViewModel.WEATHER_ICON[night.weather])
			expect(screens[1].drops).to.equal(0)
			expect(#screens[2].lines).to.equal(1)
			expect(screens[2].lines[1].text).to.equal(ShiftLandingViewModel.clock(night.minutes))
			expect(screens[2].lines[1].icon).to.equal("clock")
			expect(#screens[3].lines).to.equal(1)
			expect(screens[3].lines[1].text).to.equal("ANOMALY LEVEL")
			expect(screens[3].lines[1].icon).to.equal(nil)
		end)

		it("gives every weather its own icon key", function()
			for _, weather in ShiftLandingFormulas.WEATHER do
				local key = ShiftLandingViewModel.WEATHER_ICON[weather]
				expect(key).to.be.ok()
				expect(UIAssets.toonIcons[key]).to.be.ok()
			end
			expect(UIAssets.toonIcons.temperature).to.be.ok()
		end)

		it("is the same for the same seed and map", function()
			local a = ShiftLandingViewModel.screens(31337, "school")
			local b = ShiftLandingViewModel.screens(31337, "school")
			for index, screen in a do
				for line, value in screen.lines do
					expect(value.text).to.equal(b[index].lines[line].text)
				end
				expect(screen.drops).to.equal(b[index].drops)
			end
		end)

		it("shows the map's Gloom drops last: Office one, School two", function()
			expect(DepotConstants.OFFICE_SITE.danger).to.equal(1)
			expect(DepotConstants.SCHOOL_SITE.danger).to.equal(2)
			expect(ShiftLandingViewModel.screens(1, "office")[3].drops).to.equal(1)
			expect(ShiftLandingViewModel.screens(1, "school")[3].drops).to.equal(2)
			expect(ShiftLandingViewModel.screens(1, nil)[3].drops).to.equal(1)
		end)

		it("opens a Night Shift with NIGHT n and WEEK w on their own screen, the rest after it", function()
			local quick = ShiftLandingViewModel.screens(42, "office")
			local screens = ShiftLandingViewModel.screens(42, "office", { night = 4, week = 2 })
			expect(#screens).to.equal(4)
			expect(#screens[1].lines).to.equal(2)
			expect(screens[1].lines[1].text).to.equal("NIGHT 4")
			expect(screens[1].lines[2].text).to.equal("WEEK 2")
			expect(screens[1].lines[1].icon).to.be.ok()
			expect(screens[1].lines[2].icon).to.be.ok()
			expect(screens[1].drops).to.equal(0)
			expect(screens[2].lines[1].text).to.equal(quick[1].lines[1].text)
			expect(screens[3].lines[1].text).to.equal(quick[2].lines[1].text)
			expect(screens[4].lines[1].text).to.equal("ANOMALY LEVEL")
		end)

		it("adds a Gloom drop a week to a Night Shift's anomaly level (ShiftNightFormulas.anomaly)", function()
			expect(ShiftLandingViewModel.screens(1, "office", { night = 1, week = 1 })[4].drops).to.equal(1)
			expect(ShiftLandingViewModel.screens(1, "office", { night = 4, week = 2 })[4].drops).to.equal(2)
			expect(ShiftLandingViewModel.screens(1, "school", { night = 7, week = 3 })[4].drops).to.equal(4)
			expect(ShiftLandingViewModel.screens(1, "school", { night = 40, week = 14 })[4].drops).to.equal(5)
		end)
	end)

	describe("image", function()
		it("draws an icon only when its asset id is set", function()
			expect(ShiftLandingViewModel.image(nil)).to.equal(nil)
			expect(ShiftLandingViewModel.image("clock")).to.equal(UIAssets.toonIcons.clock)
			local empty = nil
			for name, id in UIAssets.toonIcons do
				if id == "" then
					empty = name
				end
			end
			if empty ~= nil then
				expect(ShiftLandingViewModel.image(empty)).to.equal(nil)
			end
		end)
	end)

	describe("textLeft", function()
		it("starts a line with no icon where the icon would have started", function()
			for _, layout in { "desktop", "phone" } do
				expect(ShiftLandingViewModel.textLeft(layout, { text = "ANOMALY LEVEL" })).to.equal(0)
				local empty = nil
				for name, id in UIAssets.toonIcons do
					if id == "" then
						empty = name
					end
				end
				if empty ~= nil then
					expect(ShiftLandingViewModel.textLeft(layout, { text = "38°F", icon = empty })).to.equal(0)
				end
			end
		end)

		it("keeps a line with an icon past the icon column", function()
			for _, layout in { "desktop", "phone" } do
				local metrics = ShiftLandingViewModel.METRICS[layout]
				expect(ShiftLandingViewModel.textLeft(layout, { text = "2:52 AM", icon = "clock" })).to.equal(
					metrics.icon + metrics.gap
				)
			end
		end)

		it("lines up the weather screen's lines with each other however their slots stand", function()
			local screen = ShiftLandingViewModel.screens(42, "office")[1]
			local temperature = ShiftLandingViewModel.textLeft("desktop", screen.lines[1])
			local weather = ShiftLandingViewModel.textLeft("desktop", screen.lines[2])
			if
				ShiftLandingViewModel.image(screen.lines[1].icon) == nil
				and ShiftLandingViewModel.image(screen.lines[2].icon) == nil
			then
				expect(temperature).to.equal(0)
				expect(weather).to.equal(0)
			end
		end)
	end)

	describe("drops", function()
		it("draws each drop at least as tall as the words' caps, a touch taller", function()
			for _, layout in { "desktop", "phone" } do
				local metrics = ShiftLandingViewModel.METRICS[layout]
				-- The Gloom render has room around its goo: drawn ~1.5x the text size, its goo matches the caps.
				expect(metrics.drop >= metrics.text * 1.5).to.equal(true)
				expect(metrics.drop <= metrics.text * 1.8).to.equal(true)
			end
		end)

		it("puts two drops side by side inside the readout, starting under the words", function()
			for _, layout in { "desktop", "phone" } do
				local metrics = ShiftLandingViewModel.METRICS[layout]
				expect(ShiftLandingViewModel.dropLeft(layout, 1)).to.equal(0)
				local second = ShiftLandingViewModel.dropLeft(layout, 2)
				expect(second >= metrics.drop).to.equal(true)
				expect(second + metrics.drop <= metrics.room).to.equal(true)
			end
		end)

		it("makes room under ANOMALY LEVEL for the drops", function()
			for _, layout in { "desktop", "phone" } do
				local metrics = ShiftLandingViewModel.METRICS[layout]
				expect(ShiftLandingViewModel.blockHeight(layout) >= metrics.line + metrics.drop).to.equal(true)
			end
		end)
	end)

	describe("frame", function()
		local function laptop()
			-- The 73% laptop: a 1280x720 window at the HUD's own scale, in HUD design px.
			local window = Vector2.new(1280, 720)
			local scale = PaperHudScaleViewModel.scale(window, "desktop")
			local drawn = window - Vector2.new(0, PaperHudScaleViewModel.topShift(scale))
			return PaperHudScaleViewModel.virtual(drawn, scale)
		end

		it("sits on the desktop's left side under the crew list, above the hotbar", function()
			for _, viewport in { Vector2.new(1920, 1080), laptop() } do
				for crew = 1, 4 do
					local frame = ShiftLandingViewModel.frame("desktop", viewport, crew)
					local list = ShiftCrewViewModel.listSize(false, crew)
					expect(frame.X).to.equal(24)
					expect(frame.Y >= 66 + list.Y + 12).to.equal(true)
					expect(frame.Y + ShiftLandingViewModel.blockHeight("desktop") <= viewport.Y * 0.8).to.equal(true)
				end
			end
		end)

		it("sits on the phone's left side under the Gloom meter, above the thumbstick", function()
			for _, viewport in { Vector2.new(844, 390), Vector2.new(740, 360), Vector2.new(667, 375) } do
				local frame = ShiftLandingViewModel.frame("phone", viewport, 4)
				local meter = ShiftHudViewModel.METER.phone
				expect(frame.X).to.equal(12)
				expect(frame.Y >= meter.top + meter.size.Y).to.equal(true)
				expect(
					frame.Y + ShiftLandingViewModel.blockHeight("phone")
						<= viewport.Y - ShiftCrewViewModel.PHONE_BAND.thumbTop
				).to.equal(true)
			end
		end)
	end)

	describe("rise", function()
		it("rises a little into place as it fades in", function()
			expect(ShiftLandingViewModel.rise(1)).to.equal(0)
			expect(ShiftLandingViewModel.rise(0) > 0).to.equal(true)
			expect(ShiftLandingViewModel.rise(0) <= 24).to.equal(true)
			local mid = ShiftLandingViewModel.rise(0.5)
			expect(mid > 0 and mid < ShiftLandingViewModel.rise(0)).to.equal(true)
		end)
	end)
end
