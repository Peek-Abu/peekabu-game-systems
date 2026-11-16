--!strict
--[=[
	ToonMenuBarViewModel: sizes a menu bar's tabs (ToonMenuBar) from their measured words. In order, until the tabs fit
	the room between the title plate and the wallets: shrink the text from its full size to the readable floor, then the
	same without the tab icons; if even that is too wide, the tabs keep the floor size, no icons, and scroll sideways.
	A word is never cut and a tab never runs under a wallet. (Each tab's width was guessed from its letter count with
	the text shrinking at most to 60%: on a phone GLEAM read GLEA and LOCKERS ran under the first wallet; P1 device
	check, 11-14.) `measure(text, size)` gives a word's drawn width in px (TextService in the game). Pure.

	@class ToonMenuBarViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

export type TabInput = { text: string, icon: boolean }
export type TabLayout = {
	textSize: number,
	-- Whether the tabs keep their icons.
	icons: boolean,
	-- The tabs scroll sideways (they do not fit even bare at the floor size).
	scroll: boolean,
	-- Each tab's width, in order.
	widths: { number },
}
export type Measure = (text: string, size: number) -> number

-- The label's ink stroke, drawn outside its glyphs on both sides.
local STROKE = 4

local ToonMenuBarViewModel = {}

-- A tab's top inside the bar (design px).
ToonMenuBarViewModel.TAB_TOP = 6
-- How far a selected tab reaches above its top: its lift, then the lilac ring outside its outline (ToonSurface: 3 px
-- out, a 5 px stroke). A bar must start at least this far (less TAB_TOP) under the screen's safe top.
ToonMenuBarViewModel.SELECTED_REACH = UIToonConstants.MOTION.selectedLift + UIToonConstants.DEPTH.outline + 3 + 5

-- A tab's width at `size`: its word, the stroke, and the button's own room (the icon and its gap, or the side pads).
function ToonMenuBarViewModel.tabWidth(tab: TabInput, size: number, icons: boolean, measure: Measure): number
	local room = if icons and tab.icon then size * 2 + 14 else 34
	return math.ceil(measure(tab.text, size) + STROKE + room)
end

local function widthsAt(tabs: { TabInput }, size: number, icons: boolean, measure: Measure): ({ number }, number)
	local widths: { number } = {}
	local total = 0
	for _, tab in tabs do
		local width = ToonMenuBarViewModel.tabWidth(tab, size, icons, measure)
		table.insert(widths, width)
		total += width
	end
	return widths, total
end

--[=[
	The tabs' layout in `room` px, with `gap` px after each tab, from `baseText` down to `minText`.
]=]
function ToonMenuBarViewModel.tabs(
	tabs: { TabInput },
	room: number,
	baseText: number,
	minText: number,
	gap: number,
	measure: Measure
): TabLayout
	local floor = math.min(baseText, minText)
	for _, icons in { true, false } do
		for size = baseText, floor, -1 do
			local widths, total = widthsAt(tabs, size, icons, measure)
			if total + gap * #tabs <= room then
				return { textSize = size, icons = icons, scroll = false, widths = widths }
			end
		end
	end
	local widths = widthsAt(tabs, floor, false, measure)
	return { textSize = floor, icons = false, scroll = true, widths = widths }
end

-- How much of the next tab stays in view beyond a tab scrolled to (px), so the bar still reads as "more this way".
local PEEK = 40
-- A side counts as hiding tabs past this many px (a scroll a hair off its end is the end).
local SLACK = 2

-- Where a scrolling tab row should sit (its CanvasPosition.X) so tab `index` is whole in a `view`-px window, moving as
-- little as it can from `scroll` and leaving PEEK px beyond it when there is more (owner pick U1, 2026-11-16).
function ToonMenuBarViewModel.scrollTo(
	widths: { number },
	gap: number,
	index: number,
	view: number,
	scroll: number
): number
	if widths[index] == nil then
		return scroll
	end
	local left = 0
	for i = 1, index - 1 do
		left += widths[i] + gap
	end
	local right = left + widths[index]
	local content = 0
	for i, width in widths do
		content += width + (if i > 1 then gap else 0)
	end
	local target = scroll
	if left < scroll then
		target = left - PEEK
	elseif right > scroll + view then
		target = right + PEEK - view
	end
	return math.clamp(target, 0, math.max(0, content - view))
end

export type More = { left: boolean, right: boolean }

-- Which sides of a `view`-px window scrolled to `scroll` over `content` px of tabs still hide some.
function ToonMenuBarViewModel.more(scroll: number, content: number, view: number): More
	return { left = scroll > SLACK, right = scroll + view < content - SLACK }
end

return ToonMenuBarViewModel
