--!strict
--[=[
	SortControl: the inventory's sort picker, as authored — a small square button in the well beside the
	search bar that opens a short list of sort modes beneath it.

	Replaces the placeholder pair of buttons (a mode cycler plus an up/down arrow), which was a made-up
	control that looked nothing like the game. The chrome here is transcribed from the authored `Sort`
	button: the sprite, the "..." glyph, and a dropdown of options twice the button's width, centred under
	it, in the authored order (RARITY, ALPHABETICAL, STATS).

	Open/closed is the component's own ephemeral state — nothing outside it cares whether the list is
	showing. The chosen mode and direction stay the panel's state.

	**One documented assumption.** The authored button carries an `Ascending` BoolValue, but the code
	driving it could not be read from the reference place, so the interaction that flips it is unverified.
	Picking the ALREADY-ACTIVE mode toggles direction here, and the active row shows the arrow so that is
	discoverable. If the authored control turns out to do something else, this is the one thing to change.

	@class SortControl
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Containers.InventoryViewModel)

local e = React.createElement

-- Authored order, top to bottom, with the labels the authored dropdown uses.
local OPTIONS: { { mode: InventoryViewModel.SortMode, label: string } } = {
	{ mode = "rarity", label = "RARITY" },
	{ mode = "alphabetical", label = "ALPHABETICAL" },
	{ mode = "stats", label = "STATS" },
}

-- The authored button: a translucent grey plate under the sort sprite, with a "..." glyph.
local BUTTON_COLOR = Color3.fromRGB(141, 137, 137)
local BUTTON_TRANSPARENCY = 0.45
local GLYPH = "..."
local GLYPH_COLOR = Color3.fromRGB(229, 255, 249)

-- The authored dropdown rows: twice the button's width, centred under it, one row per ~1.066 heights.
local ROW_SIZE = UDim2.fromScale(2, 1)
local ROW_X = -0.5
local ROW_FIRST_Y = 1.063
local ROW_STEP = 1.066
local ROW_COLOR = Color3.fromRGB(79, 79, 79)

local ASCENDING_MARK = "▲"
local DESCENDING_MARK = "▼"

-- The rows sit over the grid below them.
local ROW_ZINDEX = 2

export type SortControlProps = {
	sort: InventoryViewModel.SortMode,
	ascending: boolean,
	-- Called with the picked mode. Picking the active mode means "flip direction" (see the header).
	onPick: (InventoryViewModel.SortMode) -> (),
}

--[=[
	@param props SortControlProps
	@return React.ReactNode
]=]
local function SortControl(props: SortControlProps): React.ReactNode
	local open, setOpen = React.useState(false)

	local children: { [string]: React.ReactNode } = {
		glyph = e("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Tokens.font.bold,
			TextSize = Tokens.textSize.md,
			TextColor3 = GLYPH_COLOR,
			Text = GLYPH,
		}),
	}

	if open then
		for index, option in OPTIONS do
			local active = option.mode == props.sort
			local mark = if props.ascending then ASCENDING_MARK else DESCENDING_MARK
			children[option.mode] = e("TextButton", {
				Position = UDim2.fromScale(ROW_X, ROW_FIRST_Y + (index - 1) * ROW_STEP),
				Size = ROW_SIZE,
				BackgroundColor3 = ROW_COLOR,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = Tokens.font.medium,
				TextSize = Tokens.textSize.sm,
				TextColor3 = Tokens.color.text,
				Text = if active then `{option.label}  {mark}` else option.label,
				ZIndex = ROW_ZINDEX,
				[React.Event.Activated] = function()
					props.onPick(option.mode)
					setOpen(false)
				end,
			})
		end
	end

	return e("ImageButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BUTTON_COLOR,
		BackgroundTransparency = BUTTON_TRANSPARENCY,
		BorderSizePixel = 0,
		Image = UIAssets.sort.button,
		AutoButtonColor = false,
		[React.Event.Activated] = function()
			setOpen(not open)
		end,
	}, children)
end

return SortControl
