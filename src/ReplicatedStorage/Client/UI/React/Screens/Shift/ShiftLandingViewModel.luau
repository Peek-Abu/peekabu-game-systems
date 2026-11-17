--!strict
--[=[
	ShiftLandingViewModel: the landing status card (ShiftLandingCard), shown once when a crew arrives at a shift. Words
	at a kid's reading level: TONIGHT over the map's site, then Temp, Time and Weather (the night drawn from the
	shift's seed by ShiftLandingFormulas, the same for the whole crew), then Danger as the map's Gloom drops
	(DepotConstants' map sites: the Office one, the School two). `frame` places the card on the HUD's left side, under
	the meter and crew band and clear of the bottom corners (the phone's thumbstick), in HUD design px; `slide` is its
	left edge as it comes in from off screen. Pure.

	@class ShiftLandingViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotMapRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotMapRules)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftLandingFormulas = require(ReplicatedStorage.Client.Features.Shift.Utils.ShiftLandingFormulas)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftCrewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)

export type Row = {
	label: string,
	value: string,
}

export type LandingView = {
	heading: string,
	-- The map's site ("4th floor offices").
	place: string,
	-- Temp, Time, Weather, in that order.
	rows: { Row },
	danger: string,
	-- Gloom drops drawn after Danger.
	drops: number,
}

local ShiftLandingViewModel = {}

-- The card's size in HUD design px. The phone's is narrow enough to stay left of the centred Gloom meter and its
-- Gloom render on a 667 px wide phone.
ShiftLandingViewModel.SIZE = table.freeze({
	desktop = Vector2.new(300, 262),
	phone = Vector2.new(144, 128),
})

-- The card's left edge, its preferred top (desktop: under the crew list; phone: under Roblox's top-left buttons, left
-- of the centred Gloom meter) and the highest it may go, in HUD design px.
local INSET = table.freeze({ desktop = 24, phone = 12 })
local TOP = table.freeze({ desktop = 360, phone = 64 })
local MIN_TOP = table.freeze({ desktop = 90, phone = 40 })
-- Desktop: the card never reaches lower than this share of the screen (the hotbar).
local DESKTOP_FOOT = 0.8

-- `minutes` after midnight on a 12-hour clock ("1:12 AM").
function ShiftLandingViewModel.clock(minutes: number): string
	local whole = math.floor(minutes) % (24 * 60)
	local hour24 = whole // 60
	local minute = whole % 60
	local hour = hour24 % 12
	if hour == 0 then
		hour = 12
	end
	return string.format("%d:%02d %s", hour, minute, if hour24 < 12 then "AM" else "PM")
end

function ShiftLandingViewModel.card(seed: number, mapValue: ShiftTypes.MapId?): LandingView
	local map: ShiftTypes.MapId = DepotMapRules.parse(mapValue)
	local site = DepotMapRules.siteOf(map)
	local night = ShiftLandingFormulas.night(seed)
	return {
		heading = "TONIGHT",
		place = site.site,
		rows = {
			{ label = "Temp", value = `{night.temperature}°F` },
			{ label = "Time", value = ShiftLandingViewModel.clock(night.minutes) },
			{ label = "Weather", value = night.weather },
		},
		danger = "Danger",
		drops = site.danger,
	}
end

-- The card's resting top-left corner in HUD design px for `layout` on a `viewport` (HUD design px).
function ShiftLandingViewModel.frame(layout: UIPaperConstants.Layout, viewport: Vector2): Vector2
	local size = ShiftLandingViewModel.SIZE[layout]
	local preferred = if layout == "desktop" then math.max(TOP.desktop, viewport.Y * 0.34) else TOP.phone
	-- Its foot stays above the hotbar (desktop) or the thumbstick's zone (phone).
	local foot = if layout == "desktop"
		then viewport.Y * DESKTOP_FOOT
		else viewport.Y - ShiftCrewViewModel.PHONE_BAND.thumbTop
	local top = math.max(math.min(preferred, foot - size.Y), MIN_TOP[layout])
	return Vector2.new(INSET[layout], top)
end

-- The card's left edge at `alpha` (0: off the left edge, 1: at `rest`), eased out.
function ShiftLandingViewModel.slide(alpha: number, rest: number, width: number): number
	local t = math.clamp(alpha, 0, 1)
	local eased = 1 - (1 - t) ^ 3
	local away = -width - 16
	return away + (rest - away) * eased
end

return ShiftLandingViewModel
