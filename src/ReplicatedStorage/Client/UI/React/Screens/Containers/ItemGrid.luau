--!strict
--[=[
	ItemGrid: the scrolling grid of item slots. Container-agnostic on purpose — it takes an already-built
	list of `DisplayItem`s (not `StateSyncClientStore.inventory`), so the Bank can later hand it two different
	lists for its two co-visible sides. It renders each item as a `Slot`, KEYED by the item's `key`, so
	React reconciles across filter/sort changes instead of the old game's destroy-all-and-rebuild.

	Presentational: selection and clicks are lifted to the caller (`selectedKey` / `onSelect`). Actions
	on the selected item are the panel's job, not the grid's. (`containerId` is added when actions route
	to a specific container — no consumer yet.)

	@class ItemGrid
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Slot = require(ReplicatedStorage.Client.UI.React.Primitives.Slot)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Containers.InventoryViewModel)

local e = React.createElement

local CELL_PX = 90 -- the authored cell size; the portrait plate fits five across
local EMPTY_TEXT = "Nothing here."

export type ItemGridProps = {
	items: { InventoryViewModel.DisplayItem },
	selectedKey: string?,
	-- The rect rides along so the caller can anchor to what was clicked, not to what was last hovered.
	onSelect: (InventoryViewModel.DisplayItem, Slot.SlotRect) -> (),
	-- Hover reports the item under the cursor, or nil when it leaves.
	onHover: ((InventoryViewModel.DisplayItem?, Slot.SlotRect?) -> ())?,
	-- The container's PRIMARY action on right-click, without opening the card first: EQUIP from the
	-- inventory, DEPOSIT or WITHDRAW from a bank side. Named for the role rather than for the inventory's
	-- use of it — this grid does not know which container it is drawing.
	onPrimaryAction: ((InventoryViewModel.DisplayItem) -> ())?,
	-- Dragging an item out of the grid.
	onDragStart: ((InventoryViewModel.DisplayItem, Slot.SlotRect) -> ())?,
	-- Which items may be dragged at all. Absent means "all of them", which is the Bank: every item it
	-- shows has somewhere to go (the other plate). The Inventory passes one, because only an equippable
	-- unique has a drop target there.
	canDrag: ((InventoryViewModel.DisplayItem) -> boolean)?,
	onDragMove: ((Vector2) -> ())?,
	onDragEnd: ((Vector2) -> ())?,
	draggingKey: string?,
}

--[=[
	@param props ItemGridProps
	@return React.ReactNode
]=]
local function ItemGrid(props: ItemGridProps): React.ReactNode
	-- The grid's own children: the layout + padding, then one keyed Slot per item.
	local gridChildren: { [string]: React.ReactNode } = {
		layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(CELL_PX, CELL_PX),
			CellPadding = UDim2.fromOffset(Tokens.space.sm, Tokens.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
		padding = e("UIPadding", {
			PaddingTop = UDim.new(0, Tokens.space.sm),
			PaddingLeft = UDim.new(0, Tokens.space.sm),
			PaddingRight = UDim.new(0, Tokens.space.sm),
		}),
	}
	for index, item in props.items do
		local key = item.key
		-- `Slot` documents an ABSENT `onDragStart` as "not draggable, never captures the pointer", so an
		-- undraggable item must be given nil rather than a closure that no-ops internally. Wrapped
		-- unconditionally, a 6px jitter on a plain click armed a real drag on an item with no drop target
		-- anywhere: nothing moved, and the suppressed click meant the detail card did not open either.
		local draggable = props.onDragStart ~= nil and (props.canDrag == nil or props.canDrag(item))
		gridChildren[key] = e(Slot, {
			item = item,
			layoutOrder = index,
			selected = key == props.selectedKey,
			onActivate = function(rect: Slot.SlotRect)
				props.onSelect(item, rect)
			end,
			dragging = props.draggingKey == key,
			onDragStart = if draggable
				then function(rect: Slot.SlotRect)
					local onDragStart = props.onDragStart
					if onDragStart ~= nil then
						onDragStart(item, rect)
					end
				end
				else nil,
			onDragMove = props.onDragMove,
			onDragEnd = props.onDragEnd,
			onSecondaryActivate = function()
				local onPrimaryAction = props.onPrimaryAction
				if onPrimaryAction ~= nil then
					onPrimaryAction(item)
				end
			end,
			onHover = function(rect: Slot.SlotRect)
				local onHover = props.onHover
				if onHover ~= nil then
					onHover(item, rect)
				end
			end,
			onHoverEnd = function()
				local onHover = props.onHover
				if onHover ~= nil then
					onHover(nil, nil)
				end
			end,
		})
	end

	-- Root wraps the scroller so the empty-state hint can sit OUTSIDE the grid layout (a grid child
	-- would be forced to a cell) rather than being laid out as a slot.
	local rootChildren: { [string]: React.ReactNode } = {
		scroll = e("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Tokens.color.border,
		}, gridChildren),
	}
	if #props.items == 0 then
		rootChildren.empty = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.1),
			Size = UDim2.new(1, 0, 0, Tokens.textSize.md * 2),
			BackgroundTransparency = 1,
			Font = Tokens.font.body,
			TextSize = Tokens.textSize.md,
			TextColor3 = Tokens.color.textMuted,
			Text = EMPTY_TEXT,
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, rootChildren)
end

return ItemGrid
