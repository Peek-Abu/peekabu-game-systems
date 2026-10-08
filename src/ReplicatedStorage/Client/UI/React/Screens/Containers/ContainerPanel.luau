--!strict
--[=[
	ContainerPanel: one container's browsing surface — the authored plate, with the search well, sort
	control, category tabs and item grid placed on the regions its backdrop art already draws.

	Extracted from `InventoryPanel` for the Bank, which shows TWO of these side by side. That is not a
	guess at a future need: `SceneRegistry`'s header names the bank as the reason scenes exist ("one scene
	showing two co-visible container panels"), and `ItemGrid` was written container-agnostic against it.

	The authored bank agrees — its `InventoryFrame` and `BankFrame` are clones of each other — but the
	agreement is not the argument. Browsing a container is genuinely the same problem twice; what the
	authored version does about it (duplicate the instances, then instantiate the same managers over both)
	is the part not worth copying.

	**Fully controlled, and presentational like everything else here.** Every piece of state it displays
	is a prop, and it owns none. Two things forced that rather than letting it keep its own filter state:

	- the OWNER has to resolve the pinned/hovered/dragged keys against the built list, so the owner has to
	  be the one that builds it; and
	- something outside can drive the filter — clicking an equipment cell points the grid at what fits in
	  it — so the category cannot be private here.

	**What deliberately did NOT come down here: the detail card, and the drag.** Both are screen-level. The
	card is fed by the paperdoll as well as the grid, so a card owned by one container could never show an
	equipped item; and a drag crosses surfaces, so its ghost and its drop targets belong to whatever
	contains both ends. Keeping one card per SCREEN also settles by construction something the authored
	bank does not: it ships three identical `ItemInfo` frames, one per surface, which can disagree.

	@class ContainerPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Containers.InventoryViewModel)
local CategoryTabs = require(ReplicatedStorage.Client.UI.React.Screens.Containers.CategoryTabs)
local ItemGrid = require(ReplicatedStorage.Client.UI.React.Screens.Containers.ItemGrid)
local SortControl = require(ReplicatedStorage.Client.UI.React.Screens.Containers.SortControl)
local Slot = require(ReplicatedStorage.Client.UI.React.Primitives.Slot)

local e = React.createElement

-- The authored search well: a centred, bold, upper-case placeholder.
local SEARCH_PLACEHOLDER = "SEARCH..."
local SEARCH_PLACEHOLDER_COLOR = Color3.fromRGB(178, 178, 178)
local SEARCH_TEXT_COLOR = Color3.fromRGB(255, 255, 255)

type Region = { pos: UDim2, size: UDim2 }

--[=[
	A rect as fractions of the plate.
	@param x number
	@param y number
	@param width number
	@param height number
	@return Region
]=]
local function region(x: number, y: number, width: number, height: number): Region
	return { pos = UDim2.fromScale(x, y), size = UDim2.fromScale(width, height) }
end

-- Content regions, measured off the authored inventory and expressed as fractions of the plate, because
-- they have to land on the wells and recesses the backdrop art already draws.
local SEARCH_REGION = region(0.108, 0.033, 0.805, 0.045)
local SORT_REGION = region(0.924, 0.03, 0.043, 0.05)
local TABS_REGION = region(0.094, 0.09, 0.884, 0.04)
local GRID_REGION = region(0.065, 0.162, 0.888, 0.79)
local WASH_REGION = region(0.043, 0.133, 0.914, 0.828)

-- The warm diagonal wash over the plate's grid recess: a translucent stone tint that the gradient erases
-- through the middle, so it reads as light catching the top-left and bottom-right edges.
local WASH_COLOR = Color3.fromRGB(91, 86, 81)
local WASH_TRANSPARENCY = 0.7
local WASH_ROTATION = 45
local WASH_FALLOFF = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.2997, 0.74375),
	NumberSequenceKeypoint.new(0.4984, 1),
	NumberSequenceKeypoint.new(0.6993, 0.75),
	NumberSequenceKeypoint.new(1, 0),
})

-- Back-to-front within the plate: the backdrop art, the wash on its grid recess, then the content.
local BACKDROP_ZINDEX = 1
local WASH_ZINDEX = 2
local CONTENT_ZINDEX = 3
local SORT_ZINDEX = 4 -- above the grid, so the open sort list is not covered by it

export type ContainerPanelProps = {
	-- Where the plate sits. A prop because the bank puts two of these on screen at once.
	position: UDim2,
	size: UDim2,
	-- The list to show, already filtered and sorted by the owner (see the header for why).
	items: { InventoryViewModel.DisplayItem },
	-- Filter state, controlled.
	category: string,
	onCategoryChange: (string) -> (),
	search: string,
	onSearchChange: (string) -> (),
	sort: InventoryViewModel.SortMode,
	ascending: boolean,
	onSortPick: (InventoryViewModel.SortMode) -> (),
	-- Selection and drag, all reported UP.
	selectedKey: string?,
	draggingKey: string?,
	onSelect: (InventoryViewModel.DisplayItem, Slot.SlotRect) -> (),
	onHover: ((InventoryViewModel.DisplayItem?, Slot.SlotRect?) -> ())?,
	-- The container's PRIMARY action, on right-click: equip here, deposit or withdraw in the bank.
	onPrimaryAction: ((InventoryViewModel.DisplayItem) -> ())?,
	onDragStart: ((InventoryViewModel.DisplayItem, Slot.SlotRect) -> ())?,
	-- Which items may be dragged; absent means all of them (see ItemGrid).
	canDrag: ((InventoryViewModel.DisplayItem) -> boolean)?,
	onDragMove: ((Vector2) -> ())?,
	onDragEnd: ((Vector2) -> ())?,
}

--[=[
	@param props ContainerPanelProps
	@return React.ReactNode
]=]
local function ContainerPanel(props: ContainerPanelProps): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		backdrop = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.panel.inventoryBackdrop,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = BACKDROP_ZINDEX,
		}),
		wash = e("Frame", {
			Position = WASH_REGION.pos,
			Size = WASH_REGION.size,
			BackgroundColor3 = WASH_COLOR,
			BackgroundTransparency = WASH_TRANSPARENCY,
			BorderSizePixel = 0,
			ZIndex = WASH_ZINDEX,
		}, {
			gradient = e("UIGradient", { Rotation = WASH_ROTATION, Transparency = WASH_FALLOFF }),
		}),
		search = e("TextBox", {
			Position = SEARCH_REGION.pos,
			Size = SEARCH_REGION.size,
			BackgroundColor3 = Tokens.color.surfaceRaised,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Tokens.font.bold,
			TextSize = Tokens.textSize.md,
			TextColor3 = SEARCH_TEXT_COLOR,
			PlaceholderText = SEARCH_PLACEHOLDER,
			PlaceholderColor3 = SEARCH_PLACEHOLDER_COLOR,
			Text = props.search,
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Center, -- authored: the placeholder sits centred in the well
			ZIndex = CONTENT_ZINDEX,
			[React.Change.Text] = function(rbx: TextBox)
				props.onSearchChange(rbx.Text)
			end,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, Tokens.radius.sm) }),
			padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, Tokens.space.sm),
				PaddingRight = UDim.new(0, Tokens.space.sm),
			}),
		}),
		sort = e("Frame", {
			Position = SORT_REGION.pos,
			Size = SORT_REGION.size,
			BackgroundTransparency = 1,
			ZIndex = SORT_ZINDEX,
		}, {
			inner = e(SortControl, {
				sort = props.sort,
				ascending = props.ascending,
				onPick = props.onSortPick,
			}),
		}),
		tabs = e("Frame", {
			Position = TABS_REGION.pos,
			Size = TABS_REGION.size,
			BackgroundTransparency = 1,
			ZIndex = CONTENT_ZINDEX,
		}, {
			inner = e(CategoryTabs, {
				active = props.category,
				onSelect = props.onCategoryChange,
			}),
		}),
		grid = e("Frame", {
			Position = GRID_REGION.pos,
			Size = GRID_REGION.size,
			BackgroundTransparency = 1,
			ZIndex = CONTENT_ZINDEX,
		}, {
			inner = e(ItemGrid, {
				items = props.items,
				selectedKey = props.selectedKey,
				onSelect = props.onSelect,
				onHover = props.onHover,
				onPrimaryAction = props.onPrimaryAction,
				draggingKey = props.draggingKey,
				onDragStart = props.onDragStart,
				canDrag = props.canDrag,
				onDragMove = props.onDragMove,
				onDragEnd = props.onDragEnd,
			}),
		}),
	}

	return e("Frame", {
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
	}, children)
end

return ContainerPanel
