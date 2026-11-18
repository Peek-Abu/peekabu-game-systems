--!strict
--[=[
	ShiftLandingViewModel: the landing readout (ShiftLandingReadout), "big stamps" with no card behind them: each line a
	rendered icon and a big value in the HUD's toon type. Three screens, one at a time (ShiftLandingRules.screenAt):
	the temperature and the weather together, then the time, then ANOMALY LEVEL with the map's Gloom drops (DepotConstants'
	map sites: the Office one, the School two). The night is drawn from the shift's seed (ShiftLandingFormulas), the same
	for the whole crew. Words at a kid's reading level, in caps (Luckiest Guy has caps only).

	`image` is a line's icon id, nil while its UIAssets slot is "" (the line then draws no icon and its value starts
	where the icon would have, `textLeft`); `dropLeft` lays the anomaly level's drops side by side under its words. `frame` places the readout on the HUD's left side in HUD design px: on desktop under the crew list
	(its height follows the crew) and above the hotbar; on a phone under the Gloom meter and above the thumbstick.
	`rise` is how far below its place a screen is drawn while it tweens. Pure.

	@class ShiftLandingViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotMapRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotMapRules)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftLandingFormulas = require(ReplicatedStorage.Client.Features.Shift.Utils.ShiftLandingFormulas)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftCrewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type Line = {
	text: string,
	-- The line's render (nil: none, as ANOMALY LEVEL).
	icon: UIAssets.ToonIcon?,
}

export type Screen = {
	lines: { Line },
	-- Gloom drops drawn under the lines (0: none).
	drops: number,
}

export type Metrics = {
	-- The icon column (square), the gap to the value, the value's text size and each line's height.
	icon: number,
	gap: number,
	text: number,
	line: number,
	-- A Gloom drop's size (the render has room around its goo, so it is drawn taller than the text to match its caps)
	-- and the room between drops.
	drop: number,
	dropGap: number,
	-- The widest a line or the row of drops may run, from the readout's left edge.
	room: number,
}

local ShiftLandingViewModel = {}

ShiftLandingViewModel.METRICS = table.freeze({
	desktop = table.freeze({ icon = 64, gap = 14, text = 48, line = 70, drop = 76, dropGap = 4, room = 560 }),
	phone = table.freeze({ icon = 38, gap = 8, text = 28, line = 42, drop = 46, dropGap = 2, room = 320 }),
})

local WEATHER_ICON: { [ShiftLandingFormulas.Weather]: UIAssets.ToonIcon } = {
	Clear = "weatherClear",
	Cloudy = "weatherCloudy",
	Windy = "weatherWindy",
}
ShiftLandingViewModel.WEATHER_ICON = table.freeze(WEATHER_ICON)

-- The readout's left edge, its preferred top on a phone, and the gaps it keeps (HUD design px).
local INSET = table.freeze({ desktop = 24, phone = 12 })
local PHONE_TOP = 132
-- Desktop: room under the crew list (which starts 66 px down), and the share of the screen it never passes (the hotbar).
local CREW_TOP = 66
local CREW_GAP = 24
local DESKTOP_FOOT = 0.8
-- How far below its place a screen starts as it tweens in (and ends as it tweens out).
local RISE = 16

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

function ShiftLandingViewModel.screens(seed: number, mapValue: ShiftTypes.MapId?): { Screen }
	local map: ShiftTypes.MapId = DepotMapRules.parse(mapValue)
	local site = DepotMapRules.siteOf(map)
	local night = ShiftLandingFormulas.night(seed)
	return {
		{
			lines = {
				{ text = `{night.temperature}°F`, icon = "temperature" },
				{ text = string.upper(night.weather), icon = WEATHER_ICON[night.weather] },
			},
			drops = 0,
		},
		{ lines = { { text = ShiftLandingViewModel.clock(night.minutes), icon = "clock" } }, drops = 0 },
		{ lines = { { text = "ANOMALY LEVEL" } }, drops = site.danger },
	}
end

-- The icon's image id, nil when there is none or its slot is still "".
function ShiftLandingViewModel.image(icon: UIAssets.ToonIcon?): string?
	if icon == nil then
		return nil
	end
	local id = UIAssets.toonIcons[icon]
	return if id ~= nil and id ~= "" then id else nil
end

-- Where a line's text starts, from the readout's left edge: past the icon column when the line draws an icon (`image`),
-- else where the icon would have started, so a line with no icon is never indented by an empty column.
function ShiftLandingViewModel.textLeft(layout: UIPaperConstants.Layout, line: Line): number
	if ShiftLandingViewModel.image(line.icon) == nil then
		return 0
	end
	local metrics: Metrics = ShiftLandingViewModel.METRICS[layout]
	return metrics.icon + metrics.gap
end

-- The left edge of drop `index` (1..), from the readout's left edge: the drops start where the text over them does
-- (ANOMALY LEVEL has no icon) and sit side by side.
function ShiftLandingViewModel.dropLeft(layout: UIPaperConstants.Layout, index: number): number
	local metrics: Metrics = ShiftLandingViewModel.METRICS[layout]
	return (index - 1) * (metrics.drop + metrics.dropGap)
end

-- The tallest screen's height (two lines, or a line and a row of drops).
function ShiftLandingViewModel.blockHeight(layout: UIPaperConstants.Layout): number
	local metrics: Metrics = ShiftLandingViewModel.METRICS[layout]
	return math.max(2 * metrics.line, metrics.line + metrics.drop)
end

-- The readout's top-left corner in HUD design px for `layout` on a `viewport` (HUD design px) with `crew` members.
function ShiftLandingViewModel.frame(layout: UIPaperConstants.Layout, viewport: Vector2, crew: number): Vector2
	local height = ShiftLandingViewModel.blockHeight(layout)
	if layout == "desktop" then
		local list = ShiftCrewViewModel.listSize(false, math.max(crew, 1))
		local top = CREW_TOP + list.Y + CREW_GAP
		return Vector2.new(INSET.desktop, math.min(top, viewport.Y * DESKTOP_FOOT - height))
	end
	local meter = ShiftHudViewModel.METER.phone
	local foot = viewport.Y - ShiftCrewViewModel.PHONE_BAND.thumbTop
	local top = math.max(math.min(PHONE_TOP, foot - height), meter.top + meter.size.Y)
	return Vector2.new(INSET.phone, top)
end

-- Px below its place a screen `alpha` in (0..1) is drawn: RISE at 0, none at 1, eased out.
function ShiftLandingViewModel.rise(alpha: number): number
	local t = math.clamp(alpha, 0, 1)
	return RISE * (1 - t) ^ 2
end

return ShiftLandingViewModel
