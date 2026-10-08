--!strict
--[=[
	BankPanel: the bank screen — the bag on the left, the bank on the right, and items moving between
	them.

	This is the screen the scene system was built for: `SceneRegistry`'s header names it as the reason
	scenes exist rather than a flat screen stack ("one scene showing two co-visible container panels").
	Both sides are the same `ContainerPanel` the inventory uses, with their own filter state each, so
	typing in one search box cannot refilter the other.

	**One card and one drag for the whole screen.** Both live here rather than inside either panel,
	because both cross the boundary between them: a drag has an end in each container, and a card can be
	describing an item on either side. The authored bank ships three identical `ItemInfo` frames, one per
	surface, which can disagree with each other; one card cannot.

	**A transfer is decided by WHERE THE ITEM IS, not by which control was used.** `transfer` is the only
	place that decides, so right-click and drop cannot drift apart — the same rule the inventory's
	`toggleEquipped` follows. An item in the bag deposits; an item in the bank withdraws. Dropping an item
	on the side it already lives on does nothing, rather than sending a request the server would refuse.

	**Whole holdings, no quantity.** A stackable moves entirely (bank design Decision 4), so there is no
	amount control for items and no partial-transfer affordance to design around. Currency is the
	exception and gets its own strip.

	The authored `TransferItemMenu` — a stage-then-commit deposit basket — is deliberately NOT built. It
	has zero code references in the old game; the live behaviour is immediate transfer.

	@class BankPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local StatFormulas = require(ReplicatedStorage.Shared.Features.Stat.Utils.StatFormulas)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UIRenderCounters = require(ReplicatedStorage.Client.UI.UIRenderCounters)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Containers.InventoryViewModel)
local ContainerPanel = require(ReplicatedStorage.Client.UI.React.Screens.Containers.ContainerPanel)
local ItemDetail = require(ReplicatedStorage.Client.UI.React.Screens.Containers.ItemDetail)
local DetailPlacement = require(ReplicatedStorage.Client.UI.React.Screens.Containers.DetailPlacement)
local DropTargets = require(ReplicatedStorage.Client.UI.React.Screens.Containers.DropTargets)
local useContainerFilters = require(ReplicatedStorage.Client.UI.React.Hooks.useContainerFilters)
local CurrencyTransfer = require(ReplicatedStorage.Client.UI.React.Screens.Bank.CurrencyTransfer)
local CoinCounter = require(ReplicatedStorage.Client.UI.React.Screens.Bank.CoinCounter)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local Slot = require(ReplicatedStorage.Client.UI.React.Primitives.Slot)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local COMPONENT_NAME = "BankPanel"
local DEFAULT_CATEGORY = "armour" -- the authored default tab, same as the inventory
local DEFAULT_SORT: InventoryViewModel.SortMode = "alphabetical"
local NO_SELECTION = "" -- pinned/hovered/dragged key sentinel (avoids a nilable-state annotation)

-- The two container ids. They qualify every display key (see InventoryViewModel.Filter.containerId) —
-- without that, the same stackable held on both sides would carry one key and the card, the hover and
-- the drag could not tell the two holdings apart.
local BAG = "bag"
local BANK = "bank"

-- The two plate rects, resolved from the authored `Banker`: each side is a full-screen frame at
-- (0.2, 0.188) / (0.68, 0.188) carrying its plate as an `InventoryBackdrop` at a negative offset, which
-- composes to these. Same backdrop asset as the inventory's, drawn taller and narrower.
local BAG_POSITION = UDim2.fromScale(0.139, 0.132)
local BANK_POSITION = UDim2.fromScale(0.619, 0.132)
local PLATE_SIZE = UDim2.fromScale(0.263, 0.751)

-- The authored panel chrome, shared with the inventory: an oversized centred vignette over the dimmed
-- world, so only its falloff shows.
local VIGNETTE_SCALE = 1.5
local VIGNETTE_TRANSPARENCY = 0.74

-- A title over each plate, so the two identical plates are not a guessing game.
local TITLE_POSITION = UDim2.fromScale(0, -0.055)
local TITLE_SIZE = UDim2.fromScale(1, 0.045)
local BAG_TITLE = "INVENTORY"
local BANK_TITLE = "BANK"

-- The close button, off the authored `CloseMenu`.
local CLOSE_POSITION = UDim2.fromScale(0.882, 0.083)
local CLOSE_SIZE = UDim2.fromScale(0.027, 0.048)
local CLOSE_HIT_POSITION = UDim2.fromScale(0.137, 0.259)
local CLOSE_HIT_SIZE = UDim2.fromScale(0.718, 0.594)
local CLOSE_TEXT = "X"

-- Each side's coin readout, off the authored `CoinCounter` (which sits inside its side's full-screen
-- frame, so these are the composed screen rects).
local BAG_COINS_POSITION = UDim2.fromScale(0.141, 0.095)
local BANK_COINS_POSITION = UDim2.fromScale(0.786, 0.095)
local COINS_SIZE = UDim2.fromScale(0.096, 0.037)

-- Back-to-front at SCREEN level, matching the inventory's ladder.
local CATCHER_ZINDEX = 0 -- must stay below the content; see the catcher itself
local BACKDROP_ZINDEX = 1
local CONTENT_ZINDEX = 3
local DETAIL_ZINDEX = 6
local GHOST_ZINDEX = 7
local GHOST_SIZE_PX = 84 -- one fixed size wherever it was picked up, as in the inventory

local DEFAULT_VIEWPORT = Vector2.new(1920, 1080) -- only if the camera is missing, which it is not at runtime

--[=[
	The four transfer requests, INJECTED rather than required, for the same reason the inventory injects
	its equip actions: `BankServiceClient` reaches ByteNet, whose client path waits forever for a server
	that UI Labs does not have. `BankScene` supplies the real packets.
	@interface BankActions
	.depositUnique (uid: string) -> ()
	.withdrawUnique (uid: string) -> ()
	.depositStack (itemType: string) -> ()
	.withdrawStack (itemType: string) -> ()
	.depositCurrency (currencyType, amount: number) -> () -- the ONLY verb here carrying a quantity
	.withdrawCurrency (currencyType, amount: number) -> ()
]=]
export type BankActions = {
	depositUnique: (uid: string) -> (),
	withdrawUnique: (uid: string) -> (),
	depositStack: (itemType: string) -> (),
	withdrawStack: (itemType: string) -> (),
	depositCurrency: (currencyType: CurrencyConstants.CurrencyType, amount: number) -> (),
	withdrawCurrency: (currencyType: CurrencyConstants.CurrencyType, amount: number) -> (),
}

--[=[
	@interface BankPanelProps
	.actions BankActions? -- absent means the screen displays but cannot move anything (a layout-only story)
]=]
export type BankPanelProps = {
	actions: BankActions?,
	-- Closing the screen. The scene stack owns what that MEANS — this only asks. Absent in a story,
	-- where there is no stack to pop.
	onClose: (() -> ())?,
}

--[=[
	@param props BankPanelProps
	@return React.ReactNode
]=]
local function BankPanel(props: BankPanelProps): React.ReactNode
	local inventory = useAtom(StateSyncClientStore.inventory)
	local bank = useAtom(StateSyncClientStore.bank)
	-- The character's purse. nil until the currency slice first syncs, which reads as an empty balance
	-- rather than as zero-you-can-spend.
	local purse = useAtom(StateSyncClientStore.currency)
	-- The viewer's level, so the card can colour a requirement it cannot meet.
	local stats = useAtom(StateSyncClientStore.stats)

	-- One independent set per side (see the hook): the two searches must not share a box.
	local bagFilters = useContainerFilters(DEFAULT_CATEGORY, DEFAULT_SORT)
	local bankFilters = useContainerFilters(DEFAULT_CATEGORY, DEFAULT_SORT)

	-- Selection and hover are SCREEN-level, so only one card is ever open across both sides.
	local pinnedKey, setPinnedKey = React.useState(NO_SELECTION)
	local hoveredKey, setHoveredKey = React.useState(NO_SELECTION)
	local pinnedAnchor, setPinnedAnchor = React.useState(nil :: Slot.SlotRect?) -- nothing pinned at mount
	local hoveredAnchor, setHoveredAnchor = React.useState(nil :: Slot.SlotRect?) -- nothing hovered at mount

	local draggedKey, setDraggedKey = React.useState(NO_SELECTION)
	local dragPosition, setDragPosition = React.useBinding(Vector2.zero)
	-- The two plates ARE the drop targets. Refs, not state: read only at the instant of a drop.
	local platesRef = React.useRef({} :: { [string]: GuiObject }) -- empty map, no type to infer
	local bagPlateRef = React.useRef(nil :: GuiObject?) -- a ref starts empty; the type comes from here
	local bankPlateRef = React.useRef(nil :: GuiObject?) -- empty ref, so the type is stated here
	local screenRef = React.useRef(nil :: GuiObject?) -- the ghost converts into this frame's own space

	React.useEffect(function()
		UIRenderCounters.tick(COMPONENT_NAME)
	end)

	-- Publish the plate instances for the drop test once they have been attached.
	React.useEffect(function()
		local bagPlate, bankPlate = bagPlateRef.current, bankPlateRef.current
		if bagPlate ~= nil then
			platesRef.current[BAG] = bagPlate
		end
		if bankPlate ~= nil then
			platesRef.current[BANK] = bankPlate
		end
	end)

	local playerLevel: number? = if stats ~= nil then StatFormulas.levelOf(stats.totalXp) else nil

	local bagItems = InventoryViewModel.build(inventory.items, {
		containerId = BAG,
		category = bagFilters.category,
		equipSlot = bagFilters.equipSlot,
		search = bagFilters.search,
		sort = bagFilters.sort,
		ascending = bagFilters.ascending,
	})
	local bankItems = InventoryViewModel.build(bank.items, {
		containerId = BANK,
		category = bankFilters.category,
		equipSlot = bankFilters.equipSlot,
		search = bankFilters.search,
		sort = bankFilters.sort,
		ascending = bankFilters.ascending,
	})

	-- Resolve the three keys against BOTH lists, so an item filtered away on either side drops out
	-- naturally rather than leaving a card describing something no longer on screen.
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
	for _, item in bagItems do
		resolve(item)
	end
	for _, item in bankItems do
		resolve(item)
	end
	local shown = pinned or hovered

	-- The ONE place that decides what moving an item means. Derived from where the item IS, so every
	-- entry point agrees by construction: an item in the bag deposits, an item in the bank withdraws.
	-- A stackable has no uid and moves as a whole holding; a unique moves by uid.
	local function transfer(item: InventoryViewModel.DisplayItem)
		local actions = props.actions
		if actions == nil then
			return
		end
		setPinnedKey(NO_SELECTION) -- acting closes the card, whichever control asked
		local uid = item.uid
		if item.containerId == BANK then
			if uid ~= nil then
				actions.withdrawUnique(uid)
			else
				actions.withdrawStack(item.itemType)
			end
		else
			if uid ~= nil then
				actions.depositUnique(uid)
			else
				actions.depositStack(item.itemType)
			end
		end
	end

	local function onDragEnd(point: Vector2)
		local item = dragged
		setDraggedKey(NO_SELECTION)
		setPinnedKey(NO_SELECTION)
		local target = DropTargets.at(platesRef.current, point)
		-- Dropped on the OTHER plate: move it. Dropped on its own plate or on open space: nothing, rather
		-- than a request the server would only refuse.
		if item ~= nil and target ~= nil and target ~= item.containerId then
			transfer(item)
		end
	end

	-- There is one currency today; the strip is written against whichever the registry lists first, so a
	-- second one becomes a picker here rather than a rewrite.
	-- Annotated, not inferred: the singleton "jaku" widens straight back to `string` off a list index,
	-- and every currency-typed prop below would then reject it.
	local currencyType: CurrencyConstants.CurrencyType = CurrencyConstants.getValidCurrencies()[1]
	local bagCoins = if purse ~= nil then purse[currencyType] or 0 else 0
	local bankCoins = bank.currency[currencyType] or 0

	--[=[
		One side of the screen: a titled plate wired to the shared card, drag and transfer.

		It takes no container id, and that is the point: every handler reads `item.containerId` off the
		item it was given, so which way a transfer goes is a property of the ITEM rather than of the panel
		that happened to render it.
		@param title string
		@param position UDim2
		@param items { InventoryViewModel.DisplayItem }
		@param filters useContainerFilters.ContainerFilters
		@param plateRef { current: GuiObject? }
		@return React.ReactNode
	]=]
	local function side(
		title: string,
		position: UDim2,
		items: { InventoryViewModel.DisplayItem },
		filters: useContainerFilters.ContainerFilters,
		plateRef: { current: GuiObject? }
	): React.ReactNode
		return e("Frame", {
			ref = plateRef, -- the drop target IS the plate
			Position = position,
			Size = PLATE_SIZE,
			BackgroundTransparency = 1,
			ZIndex = CONTENT_ZINDEX,
		}, {
			title = e("TextLabel", {
				Position = TITLE_POSITION,
				Size = TITLE_SIZE,
				BackgroundTransparency = 1,
				Font = Tokens.font.bold,
				TextScaled = true,
				TextColor3 = Tokens.color.text,
				Text = title,
				ZIndex = CONTENT_ZINDEX,
			}),
			panel = e(ContainerPanel, {
				position = UDim2.fromScale(0, 0), -- fills the plate frame it is placed in
				size = UDim2.fromScale(1, 1),
				items = items,
				category = filters.category,
				onCategoryChange = filters.setCategory,
				search = filters.search,
				onSearchChange = filters.setSearch,
				sort = filters.sort,
				ascending = filters.ascending,
				onSortPick = filters.pickSort,
				selectedKey = pinnedKey,
				draggingKey = if draggedKey ~= NO_SELECTION then draggedKey else nil,
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
				onPrimaryAction = transfer,
				onDragStart = function(item: InventoryViewModel.DisplayItem, rect: Slot.SlotRect)
					setDraggedKey(item.key)
					setDragPosition(rect.position + rect.size / 2)
				end,
				onDragMove = setDragPosition,
				onDragEnd = onDragEnd,
			}),
		})
	end

	-- The card, in screen space beside whatever it describes.
	local overlay: { [string]: React.ReactNode } = {}
	if shown ~= nil then
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
			Size = UDim2.fromOffset(cardSize.X, cardSize.Y),
			BackgroundTransparency = 1,
			ZIndex = DETAIL_ZINDEX,
		}, {
			inner = e(ItemDetail, {
				item = shown,
				-- No cross-container comparison (design Decision 8): where a copy happens to sit is not a
				-- decision the player is making, unlike "is this better than what I am wearing".
				pinned = pinned ~= nil,
				playerLevel = playerLevel,
				equipLabel = if shown.containerId == BANK then "WITHDRAW" else "DEPOSIT",
				actions = {
					equip = function()
						transfer(shown)
					end,
				},
				onActionTaken = function()
					setPinnedKey(NO_SELECTION)
				end,
			}),
		})
	end

	return e("Frame", {
		ref = screenRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, {
		-- Click-off-to-unpin, BEHIND everything: buttons sink input but frames and labels do not, so a
		-- click on the backdrop reaches this while a click on a slot never gets past the slot.
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
		bag = side(BAG_TITLE, BAG_POSITION, bagItems, bagFilters, bagPlateRef),
		bank = side(BANK_TITLE, BANK_POSITION, bankItems, bankFilters, bankPlateRef),
		bagCoins = e(CoinCounter, {
			currencyType = currencyType,
			amount = bagCoins,
			position = BAG_COINS_POSITION,
			size = COINS_SIZE,
			zIndex = CONTENT_ZINDEX,
		}),
		bankCoins = e(CoinCounter, {
			currencyType = currencyType,
			amount = bankCoins,
			position = BANK_COINS_POSITION,
			size = COINS_SIZE,
			zIndex = CONTENT_ZINDEX,
		}),
		close = e("ImageLabel", {
			Position = CLOSE_POSITION,
			Size = CLOSE_SIZE,
			BackgroundTransparency = 1,
			Image = UIAssets.bank.closeButton,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = CONTENT_ZINDEX,
		}, {
			-- A second way out, not the only one: Escape already pops the scene, and this asks the owner
			-- to do the same thing rather than reaching for the stack itself.
			hit = e("TextButton", {
				Position = CLOSE_HIT_POSITION,
				Size = CLOSE_HIT_SIZE,
				BackgroundTransparency = 1,
				Font = Tokens.font.bold,
				TextScaled = true,
				TextColor3 = Tokens.color.text,
				Text = CLOSE_TEXT,
				AutoButtonColor = false,
				[React.Event.Activated] = function()
					local onClose = props.onClose
					if onClose ~= nil then
						onClose()
					end
				end,
			}),
		}),
		coins = e(CurrencyTransfer, {
			currencyType = currencyType,
			zIndex = CONTENT_ZINDEX,
			bagAmount = bagCoins,
			bankAmount = bankCoins,
			onDeposit = function(amount: number)
				local actions = props.actions
				if actions ~= nil then
					actions.depositCurrency(currencyType, amount)
				end
			end,
			onWithdraw = function(amount: number)
				local actions = props.actions
				if actions ~= nil then
					actions.withdrawCurrency(currencyType, amount)
				end
			end,
		}),
		-- The picked-up item riding the cursor, above both plates and deaf to input.
		dragGhost = if dragged ~= nil
			then e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = dragPosition:map(function(point: Vector2)
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
	})
end

return BankPanel
