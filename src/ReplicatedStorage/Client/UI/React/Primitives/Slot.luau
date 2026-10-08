--!strict
--[=[
	Slot: one item cell — the slot frame, the rarity border over it, the item's 2D icon, and a stack
	count. The domain primitive shared by the inventory grid and (later) the equipment paperdoll;
	deferred out of the universal primitives on purpose, because a slot only means anything in terms of
	items/rarity/stacks.

	**The art does NOT fill its cell.** Every authored slot — grid, equipment, detail card — draws its
	sprites at 0.79 of the cell, offset to (0.1, 0.123), leaving a margin the cell's own spacing relies
	on. Filling the cell instead made every slot read too large and too tight against its neighbours.

	**Layer order matters and is the authored one:** frame → rarity border → icon → count. The border is
	drawn OVER the frame, not under it — under it, the opaque frame sprite swallows the rarity entirely
	and every slot reads the same. The authored slot achieves this with a `Global`-behaviour ScreenGui
	and absolute ZIndexes (ItemFrame 1, Rarity 2, ViewportFrame 3, favorite 5); our layer hosts are
	`Sibling` on purpose, so the same numbers order a slot's own children without competing with the
	panel around it.

	Presentational: it renders a `DisplayItem` (or an empty slot) and calls `onActivate` on click; it
	never reads state or calls a service. Icons are 2D; the authored 3D viewport and the favourite star
	are later follow-ups.

	@class Slot
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local RarityDisplay = require(ReplicatedStorage.Client.UI.React.RarityDisplay)
local StatusDisplay = require(ReplicatedStorage.Client.UI.React.StatusDisplay)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Containers.InventoryViewModel)

local e = React.createElement

--[=[
	Where a slot is on screen, in pixels. Reported on hover so a caller can anchor a tooltip or detail
	card TO the slot rather than to a fixed spot.
	@interface SlotRect
	.position Vector2
	.size Vector2
]=]
export type SlotRect = { position: Vector2, size: Vector2 }

-- How far the pointer has to travel before a press counts as a drag rather than a click. Without a
-- threshold every click is a one-pixel drag, and selecting an item becomes a coin toss.
local DRAG_THRESHOLD_PX = 6

--[=[
	A pointer position, in the same space as `AbsolutePosition`.

	No inset conversion, and that is the point. `AbsolutePosition` is reported relative to the INSET area,
	not the raw screen — an inset-ignoring layer's own root measures as `(0, -58)` rather than `(0, 0)` —
	and `InputObject.Position` uses that same origin. Adding the inset here (an earlier attempt at this)
	shifted every drop by one topbar, which silently landed each equip cell's drop on the cell BELOW it.

	Anything positioned by this point still has to convert into its own parent's frame; what it must not do
	is convert the point itself.
	@param input InputObject
	@return Vector2
]=]
local function pointerPoint(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

-- The authored inset: the sprites occupy this much of the cell, at this offset.
local ART_POSITION = UDim2.fromScale(0.1, 0.123)
local ART_SIZE = UDim2.fromScale(0.79, 0.79)

local FRAME_ZINDEX = 1
local RARITY_ZINDEX = 2
local ICON_ZINDEX = 3
local STATUS_ZINDEX = 4 -- over the icon: the status dresses the whole slot, including what is in it
local COUNT_ZINDEX = 5

export type SlotProps = {
	item: InventoryViewModel.DisplayItem?,
	selected: boolean?,
	-- Click. Carries the slot's rect for the same reason hover does: whatever the click PINS has to be
	-- able to stay anchored here, without depending on a hover having happened first.
	onActivate: ((SlotRect) -> ())?,
	-- Hover is a peek at the item; the caller decides what to show for it.
	onHover: ((SlotRect) -> ())?,
	onHoverEnd: (() -> ())?,
	-- Dragging. `onDragStart` also receives the slot's rect, so a caller can size a ghost to match it, and
	-- fires only once the press passes the threshold. `onDragStart` absent means the slot is not draggable
	-- and never captures the pointer.
	onDragStart: ((SlotRect) -> ())?,
	onDragMove: ((Vector2) -> ())?,
	onDragEnd: ((Vector2) -> ())?,
	-- Marks this slot's own item as being on the cursor, so the ghost IS the item rather than a copy of it.
	dragging: boolean?,
	-- What a drag leaves behind. A grid cell is nothing but its item, so it vanishes entirely and the grid
	-- closes up. An EQUIP cell outlives whatever is in it, so it stays as an empty slot — dropping its
	-- frame out too read as picking up the equipment slot itself.
	dragLeavesEmpty: boolean?,
	-- The item's status, which tints the whole slot. A PREVIEW like the card's: nothing stores a status
	-- yet, so this only arrives from `ItemDetail` (which takes one as a prop) and from the stories. See
	-- the handover note in `ItemDetail` for what making it real needs.
	status: StatusDisplay.Status?,
	-- Right-click is the SHORTCUT for a slot's primary action — equip from the grid, unequip from the
	-- paperdoll. Distinct from `onActivate`, which only ever selects.
	onSecondaryActivate: (() -> ())?,
	layoutOrder: number?,
}

--[=[
	@param props SlotProps
	@return React.ReactNode
]=]
local function Slot(props: SlotProps): React.ReactNode
	-- While this slot's own item is on the cursor it is not drawn here — the ghost is carrying it. What is
	-- left behind depends on whether the slot exists independently of the item (see `dragLeavesEmpty`).
	local dragging = props.dragging == true
	local item = if dragging then nil else props.item
	-- Read on hover rather than tracked: the rect is only ever wanted at the moment of hovering, and a
	-- binding would re-render every slot on every layout pass.
	local rootRef = React.useRef(nil :: GuiObject?) -- a ref starts empty, so its type has to come from here

	-- Drag bookkeeping, all in refs: none of it renders, and a press that never becomes a drag must not
	-- cost a re-render. `pressOrigin` non-nil means "held but not yet past the threshold".
	local pressOriginRef = React.useRef(nil :: Vector2?) -- starts empty, so the type comes from here
	local draggingRef = React.useRef(false)
	local suppressClickRef = React.useRef(false)
	-- The handlers are read through a ref so the connections below never go stale without having to be
	-- rebuilt on every render.
	local propsRef = React.useRef(props)
	propsRef.current = props
	-- The pointer is tracked GLOBALLY, so a drag survives the cursor leaving the slot — but only while a
	-- press is actually in flight. Subscribing at mount instead would put two live handlers on every
	-- mouse movement per slot, which on a full grid is a hundred of them doing nothing.
	local connectionsRef = React.useRef({} :: { RBXScriptConnection }) -- empty list, no type to infer

	local function releasePointer()
		for _, connection in connectionsRef.current do
			connection:Disconnect()
		end
		table.clear(connectionsRef.current)
		pressOriginRef.current = nil
		draggingRef.current = false
	end

	local function capturePointer()
		if #connectionsRef.current > 0 then
			return -- already captured; a second press before a release must not double-subscribe
		end
		table.insert(
			connectionsRef.current,
			UserInputService.InputChanged:Connect(function(input: InputObject)
				local origin = pressOriginRef.current
				if origin == nil then
					return
				end
				if
					input.UserInputType ~= Enum.UserInputType.MouseMovement
					and input.UserInputType ~= Enum.UserInputType.Touch
				then
					return
				end
				local point = pointerPoint(input)
				local current = propsRef.current
				if not draggingRef.current then
					if (point - origin).Magnitude < DRAG_THRESHOLD_PX then
						return
					end
					draggingRef.current = true
					-- The release that ends a drag still lands on this button, and would otherwise read as
					-- a click and select the item you just dropped.
					suppressClickRef.current = true
					local onDragStart = current.onDragStart
					local root = rootRef.current
					if onDragStart ~= nil and root ~= nil then
						onDragStart({ position = root.AbsolutePosition, size = root.AbsoluteSize })
					end
				end
				local onDragMove = current.onDragMove
				if onDragMove ~= nil then
					onDragMove(point)
				end
			end)
		)
		table.insert(
			connectionsRef.current,
			UserInputService.InputEnded:Connect(function(input: InputObject)
				if
					input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch
				then
					return
				end
				local wasDragging = draggingRef.current
				local onDragEnd = propsRef.current.onDragEnd
				releasePointer()
				if wasDragging and onDragEnd ~= nil then
					onDragEnd(pointerPoint(input))
				end
			end)
		)
	end

	-- Unmounting mid-drag (the panel closing under the cursor) must not leave the pointer captured.
	React.useEffect(function()
		return releasePointer
	end, {})

	-- `art` holds the sprites at the authored inset; `children` is the cell itself.
	local art: { [string]: React.ReactNode } = {}
	local children: { [string]: React.ReactNode } = {
		aspect = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
	}

	-- The slot frame the icon sits in.
	art.frame = e("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = UIAssets.slot.frame,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = FRAME_ZINDEX,
	})

	-- The rarity border over the frame: a flat tint, as the authored populate path sets it. `nil` gets
	-- the empty-slot border.
	art.rarity = e("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = UIAssets.slot.rarity,
		ImageColor3 = RarityDisplay.borderColor(if item ~= nil then item.rarity else nil),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = RARITY_ZINDEX,
	})

	if item ~= nil and item.icon ~= nil then
		art.icon = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			BackgroundTransparency = 1,
			Image = item.icon,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = ICON_ZINDEX,
		})
	end

	if item ~= nil and item.quantity ~= nil and item.quantity > 1 then
		art.count = e("TextLabel", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(0.94, 0.94),
			Size = UDim2.fromScale(0.6, 0.32),
			BackgroundTransparency = 1,
			Font = Tokens.font.bold,
			TextSize = Tokens.textSize.sm,
			TextColor3 = Tokens.color.text,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			Text = tostring(item.quantity),
			ZIndex = COUNT_ZINDEX,
		}, {
			outline = e("UIStroke", { Color = Tokens.color.background, Thickness = Tokens.stroke.thin }),
		})
	end

	-- The status wash over the slot: the same tint the card's overlay uses, so an item reads as rotbound
	-- in the grid and not only once its card is open. Drawn over the icon rather than under it — the
	-- status has hold of the item itself, so leaving the icon clean would read as a frame effect.
	local statusStyle = StatusDisplay.style(props.status)
	if statusStyle ~= nil and item ~= nil then
		art.status = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.slot.rarity, -- the slot-shaped sprite, so the wash keeps the slot's silhouette
			ImageColor3 = statusStyle.slotTint,
			ImageTransparency = statusStyle.slotTransparency,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = STATUS_ZINDEX,
		})
	end

	-- `selected` deliberately draws NOTHING. The detail card anchors itself to the slot it describes, so
	-- the selection is already shown by where the card is pointing; the blue stroke on top of that was
	-- noise over art that carries its own rarity border. Kept as a prop because the callers' selection
	-- state is real and a future treatment belongs here rather than in each of them.

	children.art = e("Frame", {
		Position = ART_POSITION,
		Size = ART_SIZE,
		BackgroundTransparency = 1,
		-- A grid cell leaves NOTHING behind: showing an empty frame there would claim a slot exists at a
		-- position the grid is about to close up anyway.
		Visible = not dragging or props.dragLeavesEmpty == true,
	}, art)

	-- Clickable root when a handler is given (an invisible ImageButton), otherwise a plain frame.
	local onActivate = props.onActivate
	if onActivate ~= nil then
		return e("ImageButton", {
			ref = rootRef,
			LayoutOrder = props.layoutOrder,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = "",
			AutoButtonColor = false,
			-- A press ARMS a drag; it only becomes one past the threshold, so a click is still a click.
			-- This is why there is no `UIDragDetector` here: the detector sinks input on its parent, which
			-- silently killed both the left-click select and the right-click equip on every slot.
			[React.Event.InputBegan] = function(_rbx: ImageButton, input: InputObject)
				if
					input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch
				then
					return
				end
				-- Cleared on EVERY press, before the draggable check: the flag is only ever consumed by an
				-- `Activated` on this same slot, so a drag whose release landed elsewhere leaves it set.
				-- Gated behind `onDragStart ~= nil`, that stale `true` outlived the drag and swallowed the
				-- next click — drag an item off its equip cell and the now-empty cell (no item, so no
				-- `onDragStart`) ignored the first click on it, which is the paperdoll's main gesture.
				suppressClickRef.current = false
				if props.onDragStart == nil then
					return -- not draggable: nothing to arm, and no pointer to capture
				end
				pressOriginRef.current = pointerPoint(input)
				capturePointer()
			end,
			[React.Event.Activated] = function()
				if suppressClickRef.current then
					suppressClickRef.current = false
					return
				end
				local root = rootRef.current
				if root ~= nil then
					onActivate({ position = root.AbsolutePosition, size = root.AbsoluteSize })
				end
			end,
			[React.Event.MouseButton2Click] = function()
				local onSecondaryActivate = props.onSecondaryActivate
				if onSecondaryActivate ~= nil then
					onSecondaryActivate()
				end
			end,
			[React.Event.MouseEnter] = function()
				local onHover = props.onHover
				local root = rootRef.current
				if onHover ~= nil and root ~= nil then
					onHover({ position = root.AbsolutePosition, size = root.AbsoluteSize })
				end
			end,
			[React.Event.MouseLeave] = function()
				local onHoverEnd = props.onHoverEnd
				if onHoverEnd ~= nil then
					onHoverEnd()
				end
			end,
		}, children)
	end
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

return Slot
