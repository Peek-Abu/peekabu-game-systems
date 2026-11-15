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

return ToonMenuBarViewModel
