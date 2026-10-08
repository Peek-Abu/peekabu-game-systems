--!strict
--[=[
	InventoryPanel: the inventory screen — the framework's first real PANEL class (transient,
	input-capturing, slice-reading), the counterpart to the always-on Vitals HUD.

	It owns STATE and routes ACTIONS; it draws very little itself. The bag is a `ContainerPanel` (shared
	with the Bank, which shows two), and the gear column is `EquipmentPaperdoll`. What stays here is
	everything that spans the two: the ephemeral view state, the detail card, and the drag.

	All the filtering and sorting is the specced `InventoryViewModel`, the card's placement is
	`DetailPlacement`, and a drop's target is `DropTargets`. Rendered onto the `Panel` layer by
	`SceneHost` when the `Inventory` scene opens.

	The screen is two regions: the plate on the right, and the equipment paperdoll down the left. Both
	feed the same detail card — hovering or clicking an equipped item behaves exactly like hovering or
	clicking a grid item, which is why the hover/pin keys are resolved against both lists, and why the
	card could not live inside the `ContainerPanel` that only knows about one of them.

	**Shape: a right-anchored PORTRAIT plate**, matching the authored inventory. That is not a style
	preference — the backdrop art has the search well, tab strip and grid recess painted into it, so the
	content is placed on fractions of the plate (see the region constants) rather than flowed, which
	would drift off the art. The plate's rect is the authored one and is NOT aspect locked, because the
	authored panel isn't either. It also leaves the left of the screen free for the equipment paperdoll,
	which is where the authored game puts it.

	@class InventoryPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local StatFormulas = require(ReplicatedStorage.Shared.Features.Stat.Utils.StatFormulas)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local UIRenderCounters = require(ReplicatedStorage.Client.UI.UIRenderCounters)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Containers.InventoryViewModel)
local ItemDetail = require(ReplicatedStorage.Client.UI.React.Screens.Containers.ItemDetail)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local EquipmentPaperdoll = require(ReplicatedStorage.Client.UI.React.Screens.Inventory.EquipmentPaperdoll)
local ContainerPanel = require(ReplicatedStorage.Client.UI.React.Screens.Containers.ContainerPanel)
local useContainerFilters = require(ReplicatedStorage.Client.UI.React.Hooks.useContainerFilters)
local DetailPlacement = require(ReplicatedStorage.Client.UI.React.Screens.Containers.DetailPlacement)
local DropTargets = require(ReplicatedStorage.Client.UI.React.Screens.Containers.DropTargets)
local Slot = require(ReplicatedStorage.Client.UI.React.Primitives.Slot)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local COMPONENT_NAME = "InventoryPanel"
local DEFAULT_CATEGORY = "armour" -- the authored default tab
local DEFAULT_SORT: InventoryViewModel.SortMode = "alphabetical"
local NO_SELECTION = "" -- pinned/hovered key sentinel (avoids a nilable-state annotation)

-- The authored panel chrome. The vignette is oversized and centred so its dark corners fall outside the
-- viewport and only the falloff shows; it sits behind the plate, over the dimmed world.
local VIGNETTE_SCALE = 1.5
local VIGNETTE_TRANSPARENCY = 0.74

-- The plate's rect, straight off the authored inventory (screen fractions). Deliberately NOT aspect
-- locked: the authored panel carries no aspect constraint either, so it widens with the viewport and
-- the backdrop art is drawn to take that stretch. Locking it to the art's nominal ratio made the plate
-- far narrower than the game's at any wide viewport.
local PLATE_POSITION = UDim2.fromScale(0.652, 0.193)
local PLATE_SIZE = UDim2.fromScale(0.277, 0.649)

-- Back-to-front at SCREEN level: the dismiss catcher underneath everything, the vignette, the panel
-- content, and the detail card over the lot. The plate's own rungs live in ContainerPanel.
local CATCHER_ZINDEX = 0 -- must stay below the content; see the catcher itself
local BACKDROP_ZINDEX = 1
local CONTENT_ZINDEX = 3
local DETAIL_ZINDEX = 6
local GHOST_ZINDEX = 7 -- the dragged item rides above the card and the plate alike
-- The ghost is ONE fixed size wherever it was picked up from. Sizing it to its source cell instead made
-- the same item visibly shrink when dragged off the paperdoll (whose cells are smaller than the grid's),
-- which read as the item changing rather than moving. This sits between the two.
local GHOST_SIZE_PX = 84

-- Used only if the camera is missing, which it is not at runtime; keeps the placement total.
local DEFAULT_VIEWPORT = Vector2.new(1920, 1080)

--[=[
	The two writes the inventory can make, INJECTED rather than required.

	`EquipmentServiceClient` reaches ByteNet, whose client path blocks on a `BytenetStorage` folder that
	only a running server creates — so requiring it at module scope made this panel unrenderable in UI
	Labs, where there is no server at all. Taking the actions as a prop keeps the panel presentational,
	lets `InventoryScene` supply the real packets, and lets a story supply a local stand-in that edits the
	seeded atoms so equipping is previewable without pressing Play.
	@interface EquipmentActions
	.equip (uid: string) -> ()
	.unequip (slotId: string) -> ()
]=]
export type EquipmentActions = {
	equip: (uid: string) -> (),
	unequip: (slotId: string) -> (),
}

--[=[
	@interface InventoryPanelProps
	.equipment EquipmentActions? -- absent means the panel displays but cannot write (a layout-only story)
]=]
export type InventoryPanelProps = {
	equipment: EquipmentActions?,
}

--[=[
	@param props InventoryPanelProps
	@return React.ReactNode
]=]
local function InventoryPanel(props: InventoryPanelProps): React.ReactNode
	local inventory = useAtom(StateSyncClientStore.inventory)
	-- The viewer's level, so the detail card can colour a requirement it cannot meet. nil until the stats
	-- slice first syncs, which the card reads as "no opinion" rather than "unmet".
	local stats = useAtom(StateSyncClientStore.stats)
	local equipment = useAtom(StateSyncClientStore.equipment)
	-- The same browsing state the bank gives each of its two sides. Shared rather than re-declared here:
	-- the sort rule (picking the active mode flips direction, picking another switches to it) was written
	-- out in both places, which is precisely the drift the hook exists to prevent.
	local filters = useContainerFilters(DEFAULT_CATEGORY, DEFAULT_SORT)
	-- Two ways to show the card: hovering a slot peeks at it, clicking PINS it. A pinned card wins over a
	-- hovered one, and only a pinned card carries the action menu.
	local pinnedKey, setPinnedKey = React.useState(NO_SELECTION)
	local hoveredKey, setHoveredKey = React.useState(NO_SELECTION)
	-- Where the card should sit. TWO anchors, not one, and that is the whole point: a pinned card must
	-- stay on the slot it was pinned to, so hovering elsewhere cannot be allowed to move it. Sharing one
	-- anchor left the card showing the pinned item while sliding around after the cursor.
	local pinnedAnchor, setPinnedAnchor = React.useState(nil :: Slot.SlotRect?) -- nothing pinned at mount
	local hoveredAnchor, setHoveredAnchor = React.useState(nil :: Slot.SlotRect?) -- nothing hovered at mount

	-- The drag in flight, if any: what was picked up, and where the pointer is now. Kept in state
	-- because the ghost renders from it. The DROP TARGETS live in a ref instead — they are only read at
	-- the moment of a drop, so re-rendering when they are measured would be pure waste.
	-- Keyed, not held: the same sentinel pattern the pinned/hovered keys use, so the dragged item is
	-- resolved from the live lists and cannot go stale mid-drag if the grid re-filters underneath it.
	local draggedKey, setDraggedKey = React.useState(NO_SELECTION)
	local draggedSlot, setDraggedSlot = React.useState(NO_SELECTION)
	local dragPosition, setDragPosition = React.useBinding(Vector2.zero)
	local cellsRef = React.useRef({} :: { [string]: GuiObject }) -- empty map, no type to infer
	-- The screen root, so the ghost can convert a pointer position into an offset within it. Measured
	-- rather than assumed: this root does NOT sit at (0, 0) — an inset-ignoring layer puts it at (0, -58),
	-- so a pointer position used directly as an offset would be one topbar out.
	local screenRef = React.useRef(nil :: GuiObject?) -- a ref starts empty; the type comes from here

	React.useEffect(function()
		UIRenderCounters.tick(COMPONENT_NAME)
	end)

	local playerLevel: number? = if stats ~= nil then StatFormulas.levelOf(stats.totalXp) else nil
	local equipped = InventoryViewModel.equipped(equipment)

	-- No containerId: one container on screen, so keys stay unqualified and the grid and the paperdoll
	-- keep matching the same equipped item (see InventoryViewModel.Filter.containerId).
	local items = InventoryViewModel.build(inventory.items, {
		category = filters.category,
		equipSlot = filters.equipSlot,
		search = filters.search,
		sort = filters.sort,
		ascending = filters.ascending,
	})

	-- Resolve both keys out of the current list, so either drops out naturally if filtered away.
	-- Resolve from the grid AND the paperdoll: an equipped item can be hovered or pinned too, and it may
	-- not be in the filtered grid list at all.
	local pinned: InventoryViewModel.DisplayItem? = nil
	local hovered: InventoryViewModel.DisplayItem? = nil
	local dragged: InventoryViewModel.DisplayItem? = nil
	local function resolve(item: InventoryViewModel.DisplayItem)
		if item.key == pinnedKey then
			pinned = item
		end
		if item.key == hoveredKey then
			hovered = item
		end
		if item.key == draggedKey then
			dragged = item
		end
	end
	for _, item in items do
		resolve(item)
	end
	for _, item in equipped do
		resolve(item)
	end
	local shown = pinned or hovered

	-- The ONE place that decides what acting on an item means, so the three entry points (the card's
	-- menu, right-click, and later a drag) cannot drift apart. Which way it goes is derived from whether
	-- the item is currently WORN, not from where the click came from — the same item in the grid and on
	-- the paperdoll is the same decision.
	local function equippedSlotOf(item: InventoryViewModel.DisplayItem): string?
		local slotId = item.equipSlot
		if slotId == nil then
			return nil
		end
		local worn = equipped[slotId]
		if worn ~= nil and worn.key == item.key then
			return slotId
		end
		return nil
	end

	local function toggleEquipped(item: InventoryViewModel.DisplayItem)
		local actions = props.equipment
		if actions == nil then
			return
		end
		-- ACTING on an item closes its card, whichever way the action was asked for. The card's own menu
		-- did this and right-click did not, so equipping by right-click left a stale card describing an
		-- item that had just moved.
		setPinnedKey(NO_SELECTION)
		local wornSlot = equippedSlotOf(item)
		if wornSlot ~= nil then
			actions.unequip(wornSlot)
		elseif item.equipSlot ~= nil and item.uid ~= nil then
			-- Stackables have no uid and no equip slot, so they simply never reach here.
			actions.equip(item.uid)
		end
	end

	local function endDrag()
		setDraggedKey(NO_SELECTION)
		setDraggedSlot(NO_SELECTION)
	end

	-- A drop is a REQUEST, never an instruction: the packet carries only a uid and the server picks the
	-- slot, so landing a helmet on the greaves cell simply is not a thing the client can ask for. The
	-- check here is for feel — the drop declines instead of firing something the server would refuse.
	local function dropOnCell(item: InventoryViewModel.DisplayItem, slotId: string)
		local actions = props.equipment
		if actions ~= nil and item.equipSlot == slotId and item.uid ~= nil then
			actions.equip(item.uid)
		end
	end

	local function onDragEnd(point: Vector2)
		local item = dragged
		local fromSlot = draggedSlot
		endDrag()
		local target = DropTargets.at(cellsRef.current, point)
		local actions = props.equipment
		setPinnedKey(NO_SELECTION) -- acting closes the card; see toggleEquipped
		-- `target ~= fromSlot` makes a no-op gesture a genuine no-op: releasing an equipped item back on
		-- its OWN cell matched dropOnCell's equipSlot check and fired an equip for an item the inventory
		-- no longer holds. The server refuses it, but the request still spent a rate-limit slot. A drag
		-- from the grid has `fromSlot == NO_SELECTION`, which never equals a real slot id.
		if item ~= nil and target ~= nil and target ~= fromSlot then
			dropOnCell(item, target)
		elseif fromSlot ~= NO_SELECTION and target == nil and actions ~= nil then
			-- Dragged off the paperdoll and dropped anywhere else: take it off.
			actions.unequip(fromSlot)
		end
	end

	-- The card lives in SCREEN space, beside the slot it describes. A hovered card needs no way out —
	-- moving off the slot dismisses it — and must NOT have one, or it would swallow the hover of every
	-- other slot. A PINNED card gets the catcher below, which is a sibling of the panel's contents.
	local overlay: { [string]: React.ReactNode } = {}
	if shown ~= nil then
		-- A pinned card is anchored to what was PINNED; only an unpinned, hovered card follows the cursor.
		--
		-- The anchor is converted into this screen's OWN space before placement, rather than the placement
		-- being taught about screen origins: the card is positioned by offset within this frame, and the
		-- frame does not start at (0, 0). Working in one local space also means the edge clamps are against
		-- the area the card can actually occupy.
		local screen = screenRef.current
		local origin = if screen ~= nil then screen.AbsolutePosition else Vector2.zero
		local viewport = if screen ~= nil then screen.AbsoluteSize else DEFAULT_VIEWPORT
		local anchor = if pinned ~= nil then pinnedAnchor else hoveredAnchor
		local localAnchor: DetailPlacement.Rect? = if anchor ~= nil
			then { position = anchor.position - origin, size = anchor.size }
			else nil
		local cardPosition, cardSize = DetailPlacement.rect(localAnchor, viewport)
		overlay.detail = e("Frame", {
			Position = UDim2.fromOffset(cardPosition.X, cardPosition.Y),
			-- The card's exact rect, not a max box (see DetailPlacement): the card centres itself in here.
			Size = UDim2.fromOffset(cardSize.X, cardSize.Y),
			BackgroundTransparency = 1,
			ZIndex = DETAIL_ZINDEX,
		}, {
			inner = e(ItemDetail, {
				item = shown,
				-- What is worn in the shown item's slot, so its stat rows can compare. Comparing an
				-- equipped item against itself is suppressed inside statRows.
				equippedItem = if shown.equipSlot ~= nil then equipped[shown.equipSlot] else nil,
				pinned = pinned ~= nil,
				playerLevel = playerLevel,
				equipLabel = if shown.equipSlot ~= nil and equippedSlotOf(shown) ~= nil then "UNEQUIP" else "EQUIP",
				actions = {
					equip = if shown.equipSlot ~= nil
						then function()
							toggleEquipped(shown)
						end
						else nil,
				},
				onActionTaken = function()
					setPinnedKey(NO_SELECTION)
				end,
			}),
		})
	end

	-- The plate, right-anchored over the dimmed world, with the authored vignette behind it.
	return e("Frame", {
		ref = screenRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, {
		-- Click-off-to-unpin, BEHIND everything rather than over it. As an overlay it sat on top of the
		-- whole screen and swallowed every click on a slot — so selecting an item made it impossible to
		-- right-click that same item to equip it. Buttons sink input but plain frames and labels do not,
		-- so a click on the backdrop still reaches this while a click on a slot never gets past the slot.
		detailCatcher = if pinned ~= nil
			then e("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				ZIndex = CATCHER_ZINDEX,
				[React.Event.Activated] = function()
					setPinnedKey(NO_SELECTION)
				end,
			})
			else nil,
		vignette = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(VIGNETTE_SCALE, VIGNETTE_SCALE),
			BackgroundTransparency = 1,
			Image = UIAssets.panel.vignette,
			ImageTransparency = VIGNETTE_TRANSPARENCY,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = BACKDROP_ZINDEX,
		}),
		paperdoll = e(EquipmentPaperdoll, {
			equipped = equipped,
			selectedKey = pinnedKey,
			zIndex = CONTENT_ZINDEX,
			onSelect = function(item: InventoryViewModel.DisplayItem, rect: Slot.SlotRect)
				setPinnedKey(item.key)
				setPinnedAnchor(rect)
			end,
			cellsRef = cellsRef,
			draggingSlot = if draggedSlot ~= NO_SELECTION then draggedSlot else nil,
			onDragStart = function(slotId: string, rect: Slot.SlotRect)
				local worn = equipped[slotId]
				setDraggedKey(if worn ~= nil then worn.key else NO_SELECTION)
				setDraggedSlot(slotId)
				setDragPosition(rect.position + rect.size / 2)
			end,
			onDragMove = setDragPosition,
			onDragEnd = onDragEnd,
			onUnequip = function(slotId: string)
				local actions = props.equipment
				if actions ~= nil then
					setPinnedKey(NO_SELECTION) -- acting closes the card; see toggleEquipped
					actions.unequip(slotId)
				end
			end,
			-- Clicking a cell also points the grid at what could go in it, as the authored inventory does:
			-- a weapon cell opens the whole WEAPON category (both hands take the same items), while an
			-- armour cell narrows to that one piece, since a helmet is no use in a greaves slot.
			onFocusSlot = function(slotId: string, acceptsKind: string)
				-- Armour narrows to the ONE cell (a helmet is no use in a greaves slot); a weapon cell opens
				-- the whole category, since both hands take the same items.
				filters.focusSlot(acceptsKind, if acceptsKind == "armour" then slotId else nil)
				setPinnedKey(NO_SELECTION)
			end,
			onHover = function(item: InventoryViewModel.DisplayItem?, rect: Slot.SlotRect?)
				setHoveredKey(if item ~= nil then item.key else NO_SELECTION)
				if rect ~= nil then
					setHoveredAnchor(rect)
				end
			end,
		}),
		-- The ghost: the picked-up item riding the cursor, drawn above everything and deaf to input so it
		-- never becomes its own drop target. CENTRED on the pointer (hence the anchor point) rather than
		-- hung off its top-left corner, so the cursor holds the item instead of trailing behind it.
		dragGhost = if dragged ~= nil
			then e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = dragPosition:map(function(point: Vector2)
					-- Into this frame's own space. The drop test compares the SAME point against cell
					-- AbsolutePositions untouched, so the ghost and the target can never disagree.
					local screen = screenRef.current
					local origin = if screen ~= nil then screen.AbsolutePosition else Vector2.zero
					return UDim2.fromOffset(point.X - origin.X, point.Y - origin.Y)
				end),
				Size = UDim2.fromOffset(GHOST_SIZE_PX, GHOST_SIZE_PX),
				BackgroundTransparency = 1,
				Active = false,
				ZIndex = GHOST_ZINDEX,
			}, { inner = e(Slot, { item = dragged }) })
			else nil,
		detailOverlay = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = DETAIL_ZINDEX,
		}, overlay),
		-- The bag itself. Everything it needs is passed in, because the card and the drag it feeds both
		-- span this panel AND the paperdoll — see the ContainerPanel header.
		plate = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = CONTENT_ZINDEX,
		}, {
			inner = e(ContainerPanel, {
				position = PLATE_POSITION,
				size = PLATE_SIZE,
				items = items,
				category = filters.category,
				onCategoryChange = filters.setCategory,
				search = filters.search,
				onSearchChange = filters.setSearch,
				sort = filters.sort,
				ascending = filters.ascending,
				onSortPick = filters.pickSort,
				selectedKey = pinnedKey,
				draggingKey = if draggedSlot == NO_SELECTION and draggedKey ~= NO_SELECTION then draggedKey else nil,
				-- The only drop target on this screen is an equip cell, and only an equippable unique can
				-- land on one. Dragging anything else was a gesture that could not end in anything.
				canDrag = function(item: InventoryViewModel.DisplayItem): boolean
					return item.equipSlot ~= nil and item.uid ~= nil
				end,
				onSelect = function(item: InventoryViewModel.DisplayItem, rect: Slot.SlotRect)
					setPinnedKey(item.key)
					setPinnedAnchor(rect)
				end,
				onHover = function(item: InventoryViewModel.DisplayItem?, rect: Slot.SlotRect?)
					setHoveredKey(if item ~= nil then item.key else NO_SELECTION)
					if rect ~= nil then
						setHoveredAnchor(rect)
					end
				end,
				onPrimaryAction = toggleEquipped,
				onDragStart = function(item: InventoryViewModel.DisplayItem, rect: Slot.SlotRect)
					setDraggedKey(item.key)
					setDraggedSlot(NO_SELECTION)
					setDragPosition(rect.position + rect.size / 2)
				end,
				onDragMove = setDragPosition,
				onDragEnd = onDragEnd,
			}),
		}),
	})
end

-- A plain function component (not React.memo) so it matches SceneScreen.component's `() -> ReactNode`;
-- SceneHost only re-renders on stack changes, and this panel's re-render is cheap.
return InventoryPanel
