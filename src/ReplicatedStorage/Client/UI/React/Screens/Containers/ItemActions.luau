--!strict
--[=[
	ItemActions: the menu that hangs off the RIGHT edge of the detail card — EQUIP, EQUIP APPEARANCE,
	DISMANTLE, FAVORITE, INSPECT — on the authored `ItemInfoOptions` art.

	Shown only when the card is PINNED (clicked), never on hover: hovering a slot is a peek at the item,
	clicking it is a decision to act on it. The card is identical either way; this menu is the difference.

	Order, labels and colours come from the authored `ItemOptionsMenu`, which **overrides what the
	instances ship with** — the plates read "EQUIP ITEM"/"INSPECT ITEM" in the explorer, but the code sets
	"EQUIP"/"INSPECT" at runtime, and it reorders the rows. The code wins, so this follows the code.

	The highlight is HOVER-DRIVEN: invisible at rest, easing to 0.49 over 0.3s (Quad, Out) as the pointer
	enters a row. It is driven through a binding rather than a prop, because a re-render would otherwise
	snap the transparency back to its prop value mid-ease and kill the fade out.

	**Presentational, and deliberately inert.** Every action needs a server round trip through the
	equipment slice, and that lands with the equipment paperdoll. Handlers arrive as props so the wiring
	is a prop change, not a rewrite. A row with no handler renders in the authored disabled grey and does
	not highlight — exactly how the original treats INSPECT — so an unwired menu reads as "not yet".

	@class ItemActions
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)

local e = React.createElement

-- The authored rows in the authored ORDER (from ItemOptionsMenu's layoutOrder, skipping the consumable
-- rows, which ship invisible and belong to the deferred consumables work).
local ACTIONS: { { key: string, label: string } } = {
	{ key = "equip", label = "EQUIP" },
	{ key = "equipAppearance", label = "EQUIP APPEARANCE" },
	{ key = "dismantle", label = "DISMANTLE" },
	{ key = "favorite", label = "FAVORITE" },
	{ key = "inspect", label = "INSPECT" },
}

-- The authored menu's rect, as fractions of the CARD: hanging off its right edge.
local MENU_POSITION = UDim2.fromScale(1, 0.06)
local MENU_SIZE = UDim2.fromScale(0.622, 0.54)
local ROW_HEIGHT = 0.15
local ROW_PADDING_PX = 5

local LABEL_SIZE = UDim2.fromScale(0.724, 1)
local LABEL_POSITION = UDim2.fromScale(0.112, 0)

local HIGHLIGHT_RESTING = 1 -- invisible until hovered
local HIGHLIGHT_HOVERED = 0.49
local HIGHLIGHT_EASE_SECONDS = 0.3

local DISABLED_COLOR = Color3.fromRGB(103, 103, 103) -- the authored disabled label colour

local PLATE_ZINDEX = 1
local HIGHLIGHT_ZINDEX = 2
local LABEL_ZINDEX = 3

--[=[
	One handler per action row. Any left nil renders that row disabled.
]=]
export type ItemActionHandlers = {
	equip: (() -> ())?,
	equipAppearance: (() -> ())?,
	dismantle: (() -> ())?,
	favorite: (() -> ())?,
	inspect: (() -> ())?,
}

export type ItemActionsProps = {
	handlers: ItemActionHandlers?,
	-- Called after a row's handler runs. The authored menu closes itself on any action that is not
	-- disabled; the panel does that by unpinning.
	onActionTaken: (() -> ())?,
	-- Reflects the item's favourite state in the row's label, as the authored menu does.
	favorited: boolean?,
	-- The equip row reads UNEQUIP for something already worn, as the authored menu does.
	equipLabel: string?,
}

type RowProps = {
	label: string,
	layoutOrder: number,
	handler: (() -> ())?,
	onActionTaken: (() -> ())?,
}

--[=[
	One action row: the authored plate, a hover-eased highlight, and a centred label.
	@param props RowProps
	@return React.ReactNode
]=]
local function ActionRow(props: RowProps): React.ReactNode
	local enabled = props.handler ~= nil
	local transparency, setTransparency = React.useBinding(HIGHLIGHT_RESTING)
	local target, setTarget = React.useState(HIGHLIGHT_RESTING)

	-- Ease the highlight toward its target, matching the authored 0.3s Quad-Out tween. Driven on
	-- Heartbeat over a binding so a re-render never snaps it mid-ease.
	-- Annotated rather than cast: useEffect's dependency list is `{ unknown }`, and a `{ number }` literal
	-- does not match it invariantly. Declaring the local with the expected type gives the constructor its
	-- type directly, so no `::` is needed.
	local easeDeps: { unknown } = { target }
	React.useEffect(function()
		local from = transparency:getValue()
		if from == target then
			return
		end
		local elapsed = 0
		-- Declared before the Connect so the callback can close over it and retire ITSELF. Without that,
		-- the only teardown was a re-run or an unmount, so a finished tween kept a live Heartbeat writing
		-- an unchanged value every frame — hovering all five rows once left five of them running for as
		-- long as the card stayed open.
		local connection: RBXScriptConnection? = nil
		connection = RunService.Heartbeat:Connect(function(delta: number)
			elapsed += delta
			local alpha = math.min(elapsed / HIGHLIGHT_EASE_SECONDS, 1)
			local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			setTransparency(from + (target - from) * eased)
			if alpha >= 1 and connection ~= nil then
				connection:Disconnect()
				connection = nil
			end
		end)
		return function()
			if connection ~= nil then
				connection:Disconnect()
				connection = nil
			end
		end
	end, easeDeps)

	return e("ImageLabel", {
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
		Image = UIAssets.itemCard.actionPlate,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = PLATE_ZINDEX,
	}, {
		highlight = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.tab.highlight, -- the authored rows reuse the tab highlight sprite
			ImageTransparency = transparency,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = HIGHLIGHT_ZINDEX,
		}),
		label = e("TextButton", {
			Position = LABEL_POSITION,
			Size = LABEL_SIZE,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Font = Tokens.font.bold,
			TextScaled = true,
			TextColor3 = if enabled then Tokens.color.text else DISABLED_COLOR,
			Text = props.label,
			ZIndex = LABEL_ZINDEX,
			[React.Event.Activated] = function()
				local handler = props.handler
				if handler == nil then
					return
				end
				handler()
				local onActionTaken = props.onActionTaken
				if onActionTaken ~= nil then
					onActionTaken()
				end
			end,
			[React.Event.MouseEnter] = function()
				-- A disabled row does not light up, matching the authored guard.
				if enabled then
					setTarget(HIGHLIGHT_HOVERED)
				end
			end,
			[React.Event.MouseLeave] = function()
				setTarget(HIGHLIGHT_RESTING)
			end,
		}),
	})
end

--[=[
	@param props ItemActionsProps
	@return React.ReactNode
]=]
local function ItemActions(props: ItemActionsProps): React.ReactNode
	local handlers: { [string]: (() -> ())? } = props.handlers or {}

	local rows: { [string]: React.ReactNode } = {
		layout = e("UIGridLayout", {
			CellSize = UDim2.fromScale(1, ROW_HEIGHT),
			CellPadding = UDim2.fromOffset(ROW_PADDING_PX, ROW_PADDING_PX),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, action in ACTIONS do
		local label = action.label
		if action.key == "favorite" and props.favorited == true then
			label = "UNFAVORITE"
		elseif action.key == "equip" and props.equipLabel ~= nil then
			label = props.equipLabel
		end
		rows[action.key] = e(ActionRow, {
			label = label,
			layoutOrder = index,
			handler = handlers[action.key],
			onActionTaken = props.onActionTaken,
		})
	end

	return e("Frame", {
		Position = MENU_POSITION,
		Size = MENU_SIZE,
		BackgroundTransparency = 1,
	}, rows)
end

return ItemActions
