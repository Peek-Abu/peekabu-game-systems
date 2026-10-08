--!strict
--[=[
	EquipmentPaperdoll: the equipped-gear column down the LEFT of the inventory screen — the space the
	portrait plate was moved right to free up, and where the authored game puts it.

	Two stacked plates, as authored: a tall one behind the armour slots (helmet, pauldrons, chestplate,
	greaves) and a shorter one below it behind the weapon slots. Each cell is the same `Slot` primitive
	the grid uses, so an equipped item reads identically in both places, with the slot's name above it.

	**This is where empty slots finally appear.** Every other surface only ever renders items; a paperdoll
	is mostly empty most of the time, so `Slot`'s no-item state — the authored pale-blue border — does
	real work here rather than only in a story.

	Presentational: it takes the resolved equipment map and reports hover/click, exactly like `ItemGrid`.
	The panel owns which item the detail card is showing, so hovering an equipped item behaves the same
	as hovering a grid item.

	**Offhand is rendered INERT.** Venture splits weapons into Mainhand and Offhand; this project registers
	a single `weapon` slot (see `EquipmentConstants`, a decision that predates this screen). The weapon
	plate is drawn for two cells, so omitting the second left its lower half visibly empty. The cell is
	therefore drawn as a permanently-empty, non-interactive slot with a dimmed label — the same treatment
	the APPEARANCES tab gets. Giving it a real slot later is an `EquipmentConstants` edit plus dropping
	`inert` from its row here.

	The **APPEARANCES tab** on the column's right edge is rendered but INERT. The vanity system behind it is
	deferred, yet the tab is part of the column's silhouette, so leaving it out made the column read as
	unfinished rather than as "that feature is not in yet". It carries the authored disabled grey and no
	handler. The consumable column on the right is deferred whole, tab and all.

	@class EquipmentPaperdoll
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local Slot = require(ReplicatedStorage.Client.UI.React.Primitives.Slot)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Containers.InventoryViewModel)

local e = React.createElement

-- The column's rect on screen, straight off the authored `EquipmentFrames`.
--
-- The ASPECT LOCK is the important part and is easy to miss: a `UIAspectRatioConstraint` is not a
-- GuiObject, so it does not show up when you walk a frame's visible children. Without it the column
-- renders at its full 0.135 width scale — on a 1499px viewport that is 203px instead of the authored
-- 58px, a panel three times too wide for the slots inside it.
local COLUMN_POSITION = UDim2.fromScale(0.012, 0.228)
local COLUMN_SIZE = UDim2.fromScale(0.135, 0.357)
local COLUMN_ASPECT = 0.28

--[=[
	One equip cell: which slot it shows, its label, and where it sits as a fraction of the column.
	@interface SlotLayout
	.slotId string -- an EquipmentConstants slot id
	.label string -- the name shown above the cell
	.y number -- top edge, as a fraction of the column
	.width number -- width, as a fraction of the column (the authored cells vary slightly)
	.acceptsKind string -- the item kind this slot takes, for pointing the grid at it
	.inert boolean? -- drawn but not wired: the slot does not exist in this project's model yet
]=]
type SlotLayout = {
	slotId: string,
	label: string,
	acceptsKind: string,
	y: number,
	width: number,
	inert: boolean?,
}

-- Armour cells, top to bottom, at their authored offsets.
local ARMOUR_SLOTS: { SlotLayout } = {
	{ acceptsKind = "armour", slotId = "helmet", label = "HELMET", y = 0.03, width = 0.984 },
	{ acceptsKind = "armour", slotId = "pauldrons", label = "PAULDRONS", y = 0.276, width = 0.839 },
	{ acceptsKind = "armour", slotId = "chestplate", label = "CHESTPLATE", y = 0.536, width = 0.984 },
	{ acceptsKind = "armour", slotId = "greaves", label = "GREAVES", y = 0.776, width = 0.984 },
}

-- The weapon cells sit on the lower plate, which is drawn for both of them.
local WEAPON_SLOTS: { SlotLayout } = {
	{ acceptsKind = "weapon", slotId = "weapon", label = "MAINHAND", y = 1.038, width = 0.839 },
	{ acceptsKind = "weapon", slotId = "offhand", label = "OFF HAND", y = 1.286, width = 0.839, inert = true },
}

local CELL_X = 0.161
local CELL_HEIGHT = 0.196

-- The label sits above its cell, wider than it, as authored.
local LABEL_POSITION = UDim2.fromScale(-0.236, -0.254)
local LABEL_SIZE = UDim2.fromScale(1.442, 0.245)

-- The two plates behind the cells.
local ARMOUR_PLATE_POSITION = UDim2.fromScale(0, -0.01)
local ARMOUR_PLATE_SIZE = UDim2.fromScale(1, 1.01)
local WEAPON_PLATE_POSITION = UDim2.fromScale(0, 0.995)
local WEAPON_PLATE_SIZE = UDim2.fromScale(1, 0.531)

-- The APPEARANCES tab hanging off the column's right edge: a narrow vertical strip, capped by an arrow at
-- each end, over a warm sliver that fades out downward.
--
-- The word is stacked with EXPLICIT NEWLINES rather than by letting `TextWrapped` break it. Relying on
-- the wrap is what the authored tab does, but `TextScaled` is free to satisfy a narrow box by shrinking
-- the text instead of wrapping it — which is exactly what it did here, rendering "APPEARANCES"
-- horizontally at about a pixel per letter. One letter per line is the intent, so the text says so.
local APPEARANCES_POSITION = UDim2.fromScale(1.014, 0.11)
local APPEARANCES_SIZE = UDim2.fromScale(0.115, 0.722)
local APPEARANCES_LABEL = "APPEARANCES"
local APPEARANCES_PLATE_POSITION = UDim2.fromScale(0.003, -0.147)
local APPEARANCES_PLATE_SIZE = UDim2.fromScale(1.278, 1.329)
local APPEARANCES_PLATE_COLOR = Color3.fromRGB(255, 244, 237)
local APPEARANCES_PLATE_ROTATION = 180
local APPEARANCES_PLATE_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.71),
	NumberSequenceKeypoint.new(0.5, 0.96),
	NumberSequenceKeypoint.new(1, 1),
})
local ARROW_SIZE = UDim2.fromScale(0.947, 0.091)
local ARROW_X = -0.1
local ARROW_TOP_Y = 0.022
local ARROW_BOTTOM_Y = 0.87
local ARROW_ROTATION = 180
-- The same disabled grey the item action menu uses, so "not wired yet" reads consistently.
local DISABLED_COLOR = Color3.fromRGB(103, 103, 103)

-- Back to front: the plates, then the cells over them.
local PLATE_ZINDEX = 1
local CELL_ZINDEX = 2
-- Explicit rungs inside the tab: the authored plate and label share a ZIndex and rely on tree order,
-- which React children (a dictionary) do not have.
local TAB_PLATE_ZINDEX = 1
local TAB_LABEL_ZINDEX = 2

export type EquipmentPaperdollProps = {
	-- Slot id → the item in it. A slot absent from this map renders empty.
	equipped: { [string]: InventoryViewModel.DisplayItem },
	selectedKey: string?,
	-- The rect rides along so the caller can anchor to the cell that was clicked (see ItemGrid).
	onSelect: (InventoryViewModel.DisplayItem, Slot.SlotRect) -> (),
	onHover: ((InventoryViewModel.DisplayItem?, Slot.SlotRect?) -> ())?,
	-- Clicking a cell also asks the grid to show what could go in it: the slot id and the kind it takes.
	-- Fired for EMPTY cells too — pointing the grid at a slot you are trying to fill is the main use.
	onFocusSlot: ((string, string) -> ())?,
	-- Right-click empties a filled cell, without opening the card first.
	onUnequip: ((string) -> ())?,
	-- A registry the cells write themselves into, so the panel can hit-test a drop against them. The
	-- panel measures at DROP time rather than being handed rects: a measurement taken on render can be
	-- one layout pass stale, and a drop is exactly when the truth is wanted.
	cellsRef: { current: { [string]: GuiObject } }?,
	-- Dragging a worn item off the paperdoll.
	onDragStart: ((string, Slot.SlotRect) -> ())?,
	onDragMove: ((Vector2) -> ())?,
	onDragEnd: ((Vector2) -> ())?,
	draggingSlot: string?,
	-- The rung this component sits on in the CALLER's screen-level ladder. Passed rather than defaulted:
	-- an unset ZIndex is 1, which is the same rung the screens give their full-screen vignette, and React
	-- children come from a DICTIONARY whose order is undefined — so which of the two drew on top was left
	-- to a hash walk (the hazard ItemDetail already documents having been bitten by).
	zIndex: number?,
}

--[=[
	@param props EquipmentPaperdollProps
	@return React.ReactNode
]=]
local function EquipmentPaperdoll(props: EquipmentPaperdollProps): React.ReactNode
	-- One ref OBJECT per cell, built once and reused. Object refs rather than callback refs on purpose:
	-- they are the form already proven to work here (`Slot` measures its own root the same way), and a
	-- drop target that silently fails to register is invisible until someone reports that dragging does
	-- nothing.
	local cellRefs = React.useRef(nil :: { [string]: { current: GuiObject? } }?) -- empty ref, type stated here
	if cellRefs.current == nil then
		local built: { [string]: { current: GuiObject? } } = {}
		for _, layout in ARMOUR_SLOTS do
			built[layout.slotId] = { current = nil }
		end
		for _, layout in WEAPON_SLOTS do
			built[layout.slotId] = { current = nil }
		end
		cellRefs.current = built
	end
	local refs = cellRefs.current

	-- Publish the live instances upward after every render, once the refs have been attached. The caller
	-- measures them at DROP time rather than being handed rects, so a value taken a layout pass too early
	-- can never be the thing a drop is tested against.
	React.useEffect(function()
		local cells = props.cellsRef
		if cells == nil or refs == nil then
			return
		end
		for slotId, ref in refs do
			local instance = ref.current
			if instance ~= nil then
				cells.current[slotId] = instance
			end
		end
	end)

	local children: { [string]: React.ReactNode } = {
		aspect = e("UIAspectRatioConstraint", { AspectRatio = COLUMN_ASPECT }),
		armourPlate = e("ImageLabel", {
			Position = ARMOUR_PLATE_POSITION,
			Size = ARMOUR_PLATE_SIZE,
			BackgroundTransparency = 1,
			Image = UIAssets.equipment.armourBackdrop,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = PLATE_ZINDEX,
		}),
		weaponPlate = e("ImageLabel", {
			Position = WEAPON_PLATE_POSITION,
			Size = WEAPON_PLATE_SIZE,
			BackgroundTransparency = 1,
			Image = UIAssets.equipment.weaponBackdrop,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = PLATE_ZINDEX,
		}),
	}

	local function addCell(layout: SlotLayout)
		local inert = layout.inert == true
		-- An inert cell has no slot in the model, so it can never hold anything and takes no input.
		local item = if inert then nil else props.equipped[layout.slotId]
		local cell: { [string]: React.ReactNode } = {
			-- Square, as authored: the constraint fits the cell inside its (wider) declared rect.
			aspect = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
			label = e("TextLabel", {
				Position = LABEL_POSITION,
				Size = LABEL_SIZE,
				BackgroundTransparency = 1,
				Font = Tokens.font.bold,
				TextScaled = true,
				TextColor3 = if inert then DISABLED_COLOR else Tokens.color.text,
				Text = layout.label,
			}),
			slot = if inert
				then e(Slot, {})
				else e(Slot, {
					item = item,
					selected = item ~= nil and item.key == props.selectedKey,
					onActivate = function(rect: Slot.SlotRect)
						-- Point the grid at this slot whether or not it holds anything: an empty cell is
						-- exactly when you want to see what fits.
						local onFocusSlot = props.onFocusSlot
						if onFocusSlot ~= nil then
							onFocusSlot(layout.slotId, layout.acceptsKind)
						end
						if item ~= nil then
							props.onSelect(item, rect)
						end
					end,
					dragging = props.draggingSlot == layout.slotId,
					dragLeavesEmpty = true, -- an equip slot outlives the item in it
					onDragStart = if item ~= nil
						then function(rect: Slot.SlotRect)
							local onDragStart = props.onDragStart
							if onDragStart ~= nil then
								onDragStart(layout.slotId, rect)
							end
						end
						else nil,
					onDragMove = props.onDragMove,
					onDragEnd = props.onDragEnd,
					onSecondaryActivate = function()
						-- Only meaningful on a filled cell; an empty one has nothing to remove.
						local onUnequip = props.onUnequip
						if onUnequip ~= nil and item ~= nil then
							onUnequip(layout.slotId)
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
				}),
		}

		children[layout.slotId] = e("Frame", {
			Position = UDim2.fromScale(CELL_X, layout.y),
			Size = UDim2.fromScale(layout.width, CELL_HEIGHT),
			BackgroundTransparency = 1,
			ZIndex = CELL_ZINDEX,
			-- INERT cells register too, on purpose: a drop on a cell that cannot take the item should do
			-- nothing, and an unregistered cell would instead read as "dropped on open space" and unequip.
			ref = if refs ~= nil then refs[layout.slotId] else nil,
		}, cell)
	end

	-- One letter per line (see the constants): deterministic, unlike leaving it to TextScaled + wrapping.
	local stackedLabel = table.concat(string.split(APPEARANCES_LABEL, ""), "\n")

	local function arrow(y: number): React.ReactNode
		return e("ImageLabel", {
			Position = UDim2.fromScale(ARROW_X, y),
			Size = ARROW_SIZE,
			Rotation = ARROW_ROTATION,
			BackgroundTransparency = 1,
			Image = UIAssets.equipment.appearancesArrow,
			ScaleType = Enum.ScaleType.Stretch,
		})
	end

	children.appearances = e("Frame", {
		Position = APPEARANCES_POSITION,
		Size = APPEARANCES_SIZE,
		BackgroundTransparency = 1,
		ZIndex = CELL_ZINDEX,
	}, {
		plate = e("Frame", {
			Position = APPEARANCES_PLATE_POSITION,
			Size = APPEARANCES_PLATE_SIZE,
			BackgroundColor3 = APPEARANCES_PLATE_COLOR,
			BorderSizePixel = 0,
			ZIndex = TAB_PLATE_ZINDEX,
		}, {
			fade = e("UIGradient", { Rotation = APPEARANCES_PLATE_ROTATION, Transparency = APPEARANCES_PLATE_FADE }),
			topArrow = arrow(ARROW_TOP_Y),
			bottomArrow = arrow(ARROW_BOTTOM_Y),
		}),
		-- A label, not a button: there is nothing behind it to activate yet.
		label = e("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Tokens.font.bold,
			TextScaled = true,
			TextColor3 = DISABLED_COLOR,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = stackedLabel,
			ZIndex = TAB_LABEL_ZINDEX,
		}),
	})

	for _, layout in ARMOUR_SLOTS do
		addCell(layout)
	end
	for _, layout in WEAPON_SLOTS do
		addCell(layout)
	end

	return e("Frame", {
		Position = COLUMN_POSITION,
		Size = COLUMN_SIZE,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, children)
end

return EquipmentPaperdoll
