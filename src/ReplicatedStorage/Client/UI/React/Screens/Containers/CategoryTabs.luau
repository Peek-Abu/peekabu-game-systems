--!strict
--[=[
	CategoryTabs: the ARMOR / WEAPON / ITEMS / MISC row that picks which item KIND the grid shows — the
	framework's answer to the old game's hand-rolled `CategoryTabsManager`.

	Presentational: it renders the active tab and reports a pick (`onSelect(kind)`); the panel owns the
	active-category state. The label→kind mapping (ITEMS → consumable) lives here, at the UI edge, so the
	view-model stays a pure kind filter.

	**Not built on the `Button` primitive, on purpose.** The authored tab is a bare centred label with no
	fill, no padding, no corner, no hover and no selected colour — it shares nothing with Button except
	being clickable, so wrapping Button meant fighting its styling off. The tabs are equal-width cells
	spanning the row (as authored), and the ONLY selection cue is a highlight sprite behind the active
	one, which must be a sibling BEHIND the button because a child would draw over its text.

	@class CategoryTabs
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)

local e = React.createElement

-- Authored tab order, with each label's underlying item kind.
local TABS: { { label: string, kind: string } } = {
	{ label = "ARMOR", kind = "armour" },
	{ label = "WEAPON", kind = "weapon" },
	{ label = "ITEMS", kind = "consumable" },
	{ label = "MISC", kind = "misc" },
}

-- Every tab reads the same; the highlight is the only state.
local TAB_COLOR = Color3.fromRGB(226, 226, 226)

-- The authored highlight: slightly wider than its tab and nudged left to sit centred behind it. Below
-- the button's ZIndex so the sprite stays behind the label.
local HIGHLIGHT_SIZE = UDim2.fromScale(1.178, 1.01)
local HIGHLIGHT_POSITION = UDim2.fromScale(-0.082, 0)
local HIGHLIGHT_TRANSPARENCY = 0.5
local HIGHLIGHT_ZINDEX = 1
local LABEL_ZINDEX = 2

export type CategoryTabsProps = {
	active: string, -- the active item kind
	onSelect: (string) -> (),
}

--[=[
	@param props CategoryTabsProps
	@return React.ReactNode
]=]
local function CategoryTabs(props: CategoryTabsProps): React.ReactNode
	local cellWidth = 1 / #TABS

	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index, tab in TABS do
		-- A cell so the highlight can sit behind the label rather than over it.
		local cell: { [string]: React.ReactNode } = {
			label = e("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				AutoButtonColor = false, -- the authored tabs have no hover or press state
				Font = Tokens.font.bold,
				TextSize = Tokens.textSize.sm,
				TextColor3 = TAB_COLOR,
				Text = tab.label,
				ZIndex = LABEL_ZINDEX,
				[React.Event.Activated] = function()
					props.onSelect(tab.kind)
				end,
			}),
		}
		if tab.kind == props.active then
			cell.highlight = e("ImageLabel", {
				Size = HIGHLIGHT_SIZE,
				Position = HIGHLIGHT_POSITION,
				BackgroundTransparency = 1,
				Image = UIAssets.tab.highlight,
				ImageTransparency = HIGHLIGHT_TRANSPARENCY,
				ScaleType = Enum.ScaleType.Stretch,
				ZIndex = HIGHLIGHT_ZINDEX,
			})
		end

		children[tab.kind] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromScale(cellWidth, 1),
			BackgroundTransparency = 1,
		}, cell)
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

return CategoryTabs
