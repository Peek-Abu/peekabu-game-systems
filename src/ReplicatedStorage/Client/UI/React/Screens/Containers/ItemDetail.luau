--!strict
--[=[
	ItemDetail: the selected item's detail card, on the authored `ItemInfo` art — the item's own slot, its
	name and kind, the primary stat, rarity, description and level requirement.

	Like the plate around it, the card is ART with its sections painted in, so the content sits on measured
	fractions of the card and it holds the authored 0.69 aspect, centring itself in whatever container it
	is given.

	**Layer order, which is not obvious:** the plate and the stat wash are the BACK layer, the rarity wash
	sits OVER them, the text over that, and the outlines and separation rules last. The stat wash
	(`PrimaryStatColor`) is a full-card sprite, not a strip behind one line, and it is UNDER the rarity
	wash — putting it on top washes the rarity colour out.

	**The rarity wash is a tint AND a fixed gradient.** Unlike the slot — whose populate path destroys its
	gradient and sets a flat tint — this one keeps its gradient: a warm 5-stop shimmer that is the SAME
	for every rarity, multiplied by a per-rarity `ImageColor3`. So the shimmer is a constant here, not
	something derived per rarity. (The authored per-rarity 5-stop sequence belongs to the `Status`
	overlay, which is the rotbound treatment — not modelled, so not built.)

	Text is `TextScaled` throughout, as the authored card is: the regions fix the size, so the labels fill
	them rather than carrying their own point sizes.

	Presentational, and only ever mounted with an item, so it has no empty state.

	**The primary stat line is RESERVED and empty on purpose.** The authored line is the weapon's DAMAGE,
	which is a different concept from the stat bonuses below it — in the game and in the lore, an item's
	damage/armour is its headline number, not one of its rot-endurance-style modifiers. This project models
	no such field, so the region holds its place (and its backing wash) rather than being filled with the
	largest ordinary bonus, which would conflate the two. It fills in when the combat work adds the field.

	The stat bonuses the item DOES carry render below it, in the authored `SecondaryStats` grid. Nothing
	shifts to fill the gap — every region is absolutely placed on the art — so the reserved line is simply
	blank until there is a value for it. Its measured rect, kept here so it is not re-derived later:
	`region(0.065, 0.2, 0.644, 0.07)`.

	**Still empty, for want of data:** the `(+N)` delta against the currently equipped item, and the status
	line ("ITEM IS BIND ON EQUIP", rotbound, locked) — no such flag is modelled, and whether every
	weapon/armour is bind-on-equip could not be checked, because the reference place holds the authored
	INSTANCES but not the authored CODE.

	⚠ **ROTBOUND IS A PREVIEW.** `status` arrives as a PROP and nothing sets it outside the story. Making
	it real needs, in order: a field on the entry (`status: "rotbound"?` on `UniqueEntry`, since the
	authored `item.Rotbound` is per-item rather than per-type), that field carried onto `DisplayItem` by
	`toDisplay`, the slice validator taught to accept it, and the panel passing `shown.status` down. The
	presentation here and in `StatusDisplay` needs no change when that happens. The authored game ships
	pre-scrambled twin strings; `StatusDisplay.obscure` derives them instead, so no content is needed.

	@class ItemDetail
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local RarityDisplay = require(ReplicatedStorage.Client.UI.React.RarityDisplay)
local StatDisplay = require(ReplicatedStorage.Client.UI.React.StatDisplay)
local StatusDisplay = require(ReplicatedStorage.Client.UI.React.StatusDisplay)
local ItemActions = require(ReplicatedStorage.Client.UI.React.Screens.Containers.ItemActions)
local Slot = require(ReplicatedStorage.Client.UI.React.Primitives.Slot)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Containers.InventoryViewModel)

local e = React.createElement

-- The authored card's proportions.
local CARD_ASPECT = 0.69

local NO_STAT = "" -- hoveredStat sentinel

type Region = { pos: UDim2, size: UDim2 }

--[=[
	A rect as fractions of the card.
	@param x number
	@param y number
	@param width number
	@param height number
	@return Region
]=]
local function region(x: number, y: number, width: number, height: number): Region
	return { pos = UDim2.fromScale(x, y), size = UDim2.fromScale(width, height) }
end

-- Content regions, measured off the authored `ItemInfo`.
local SLOT_REGION = region(0, -0.004, 0.285, 0.201)
local NAME_REGION = region(0.305, 0.02, 0.644, 0.099)
local KIND_REGION = region(0.305, 0.114, 0.52, 0.062)
local RARITY_REGION = region(0.179, 0.555, 0.644, 0.07)
local DESCRIPTION_REGION = region(0.065, 0.635, 0.884, 0.186)
local LEVEL_REGION = region(0.065, 0.919, 0.884, 0.058)
local STATUS_REGION = region(0.065, 0.841, 0.884, 0.052)
local STAT_REGION = region(0.065, 0.2, 0.644, 0.07)
-- The authored SecondaryStats grid, directly under the primary line.
local SECONDARY_REGION = region(0.066, 0.292, 0.883, 0.26)
local SECONDARY_ROW_HEIGHT = 0.2 -- authored UIGridLayout cell height
local SECONDARY_ROW_PADDING = 0.01

-- The rarity wash: slightly wider than the card and nudged left, as authored.
local RARITY_WASH_REGION = region(-0.008, 0, 1.008, 1)
-- Its fixed warm shimmer — the same for every rarity; the per-rarity colour is the tint over it.
local RARITY_SHIMMER = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 234, 160)),
	ColorSequenceKeypoint.new(0.31, Color3.fromRGB(255, 215, 197)),
	ColorSequenceKeypoint.new(0.51, Color3.fromRGB(255, 178, 110)),
	ColorSequenceKeypoint.new(0.78, Color3.fromRGB(255, 179, 144)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 204, 123)),
})
local RARITY_SHIMMER_ROTATION = 45

-- The primary stat line's authored colours: cream normally, an alarm red once a stack is full.
local STAT_COLOR = Color3.fromRGB(255, 233, 203)
local STAT_FULL_COLOR = Color3.fromRGB(255, 85, 70)

-- Stat rows: the base colour, and the authored comparison colours for a gain and a loss.
local STAT_ROW_COLOR = Color3.fromRGB(216, 216, 216)
local STAT_GAIN_COLOR = Color3.fromRGB(135, 255, 149)
local STAT_LOSS_COLOR = Color3.fromRGB(255, 106, 106)

-- The status line's authored colour.
local STATUS_COLOR = Color3.fromRGB(255, 243, 225)

-- The stat tooltip: a small panel to the LEFT of the card, level with the row being hovered, as the
-- authored TooltipManager places it (offset back from the row's own position). Its Y is derived from the
-- row's index in the grid rather than measured, so it needs no ref or layout read.
local TOOLTIP_WIDTH = 0.9
local TOOLTIP_X = -0.95
local TOOLTIP_HEIGHT = 0.16
local TOOLTIP_BACKGROUND = Color3.fromRGB(24, 22, 20)
local TOOLTIP_TRANSPARENCY = 0.1
local TOOLTIP_ZINDEX = 6

-- The level row, coloured by whether the player actually meets the requirement.
local LEVEL_MET_COLOR = Color3.fromRGB(239, 239, 239)
local LEVEL_UNMET_COLOR = Color3.fromRGB(255, 137, 129)

-- The full-card stat wash's authored tint (a muted rose).
local STAT_WASH_COLOR = Color3.fromRGB(255, 157, 159)

-- Back to front: the plate and the stat wash, the rarity wash over them, the text, then the outlines and
-- rules last (they are borders, so they must draw over everything).
-- Every layer gets its OWN rung. The authored card has the plate and the stat wash both at Z=5 and
-- relies on tree order to put the wash on top; React children come from a DICTIONARY, whose order is
-- undefined, so sharing a rung there let the opaque plate draw over the wash at random and swallow the
-- stat band entirely.
local PLATE_ZINDEX = 1
local STAT_WASH_ZINDEX = 2
local RARITY_ZINDEX = 3
local TEXT_ZINDEX = 4
local STATUS_ZINDEX = 5 -- over the text it obscures
local OUTLINE_ZINDEX = 6

export type ItemDetailProps = {
	item: InventoryViewModel.DisplayItem,
	-- PREVIEW ONLY (see the header): the item's status, as a prop rather than data.
	status: StatusDisplay.Status?,
	-- Whatever is worn in this item's slot, so the stat rows can show what a swap would gain or cost.
	-- nil means nothing to compare against, and the rows render as plain values.
	equippedItem: InventoryViewModel.DisplayItem?,
	-- The viewer's level, so the requirement line can show whether they meet it. nil while unsynced,
	-- which renders the line in its neutral "met" colour rather than falsely alarming.
	playerLevel: number?,
	-- Pinned (clicked) cards carry the action menu; hovered ones are a peek and do not.
	pinned: boolean?,
	actions: ItemActions.ItemActionHandlers?,
	equipLabel: string?,
	onActionTaken: (() -> ())?,
}

--[=[
	A `TextScaled` label placed on one of the card's regions, as the authored labels are.
	@param area Region
	@param color Color3
	@param align Enum.TextXAlignment
	@param text string
	@return React.ReactNode
]=]
local function line(
	area: Region,
	color: Color3,
	align: Enum.TextXAlignment,
	text: string,
	statusStyle: StatusDisplay.StatusStyle?
): React.ReactNode
	-- A status lays its gradient over the label, which is what makes the treatment read as one thing
	-- rather than a set of recoloured labels (the authored card carries 16 copies of this gradient).
	local dressing: { [string]: React.ReactNode }? = nil
	if statusStyle ~= nil then
		local children: { [string]: React.ReactNode } = {}
		children.gradient = e("UIGradient", { Color = statusStyle.textGradient })
		dressing = children
	end
	return e("TextLabel", {
		Position = area.pos,
		Size = area.size,
		BackgroundTransparency = 1,
		Font = Tokens.font.bold, -- the authored card is bold throughout
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = color,
		TextXAlignment = align,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = text,
		ZIndex = TEXT_ZINDEX,
	}, dressing)
end

--[=[
	A full-card sprite layer.
	@param image string
	@param zIndex number
	@param tint Color3?
	@return React.ReactNode
]=]
local function layer(image: string, zIndex: number, tint: Color3?): React.ReactNode
	return e("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = image,
		ImageColor3 = tint,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = zIndex,
	})
end

--[=[
	One stat row's text: "NAME: value" with an optional coloured "(+n)" / "(-n)" delta. Zero deltas are
	omitted rather than shown as "(+0)", matching the authored rule that only compares when the values
	actually differ.
	@param row InventoryViewModel.StatRow
	@return string
]=]
local function statRowText(row: InventoryViewModel.StatRow): string
	local label = `{StatDisplay.label(row.id)}: {row.value}`
	local delta = row.delta
	if delta == nil or delta == 0 then
		return label
	end
	local colour = if delta > 0 then STAT_GAIN_COLOR else STAT_LOSS_COLOR
	local sign = if delta > 0 then "+" else ""
	local r, g, b = math.floor(colour.R * 255), math.floor(colour.G * 255), math.floor(colour.B * 255)
	return `{label} <font color="rgb({r},{g},{b})">({sign}{delta})</font>`
end

--[=[
	@param props ItemDetailProps
	@return React.ReactNode
]=]
local function ItemDetail(props: ItemDetailProps): React.ReactNode
	local item = props.item
	local statusStyle = StatusDisplay.style(props.status)
	local obscured = statusStyle ~= nil and statusStyle.obscuresDetail
	-- Which stat row the pointer is over, for its tooltip. A sentinel rather than nil, so the state stays
	-- a plain string.
	local hoveredStat, setHoveredStat = React.useState(NO_STAT)

	local children: { [string]: React.ReactNode } = {
		aspect = e("UIAspectRatioConstraint", { AspectRatio = CARD_ASPECT }),

		-- The plate carries an opaque white backing under its sprite, as authored.
		plate = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Image = UIAssets.itemCard.plate,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = PLATE_ZINDEX,
		}),
		statWash = layer(UIAssets.itemCard.statBar, STAT_WASH_ZINDEX, STAT_WASH_COLOR),

		-- The item's own slot, top-left, square, using the same primitive the grid does.
		slot = e("Frame", {
			Position = SLOT_REGION.pos,
			Size = SLOT_REGION.size,
			BackgroundTransparency = 1,
			ZIndex = PLATE_ZINDEX,
		}, {
			aspect = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
			-- The status rides along, so the card's own slot is dressed like the rest of the card rather
			-- than sitting in it as the one untouched piece.
			inner = e(Slot, { item = item, status = props.status }),
		}),

		rarityWash = e("ImageLabel", {
			Position = RARITY_WASH_REGION.pos,
			Size = RARITY_WASH_REGION.size,
			BackgroundTransparency = 1,
			Image = UIAssets.itemCard.rarityBar,
			ImageColor3 = RarityDisplay.accentColor(item.rarity),
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = RARITY_ZINDEX,
		}, {
			shimmer = e("UIGradient", { Color = RARITY_SHIMMER, Rotation = RARITY_SHIMMER_ROTATION }),
		}),

		-- Upper-cased HERE rather than in the item data: the caps are how this card is set, not part of the
		-- item's name, and the same name is shown unshouted elsewhere.
		name = line(NAME_REGION, Tokens.color.text, Enum.TextXAlignment.Center, string.upper(item.name)),
		kind = line(KIND_REGION, Tokens.color.text, Enum.TextXAlignment.Left, string.upper(item.kind)),
		rarity = line(RARITY_REGION, Tokens.color.text, Enum.TextXAlignment.Center, string.upper(item.rarity)),

		separators = layer(UIAssets.itemCard.separators, OUTLINE_ZINDEX),
		outlines = layer(UIAssets.itemCard.outlines, OUTLINE_ZINDEX),
	}

	-- The stat rows, in the authored grid beneath the (reserved) primary line. RichText so the delta can
	-- be coloured independently of the value, exactly as the authored template does.
	local rows = InventoryViewModel.statRows(item, props.equippedItem)
	if #rows > 0 then
		local rowNodes: { [string]: React.ReactNode } = {
			layout = e("UIGridLayout", {
				CellSize = UDim2.fromScale(1, SECONDARY_ROW_HEIGHT),
				CellPadding = UDim2.fromScale(SECONDARY_ROW_PADDING, SECONDARY_ROW_PADDING),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		-- Built once: every obscured row wears the same gradient, and a typed local keeps the optional
		-- child table from widening to `boolean` at the call site.
		local rowDressing: { [string]: React.ReactNode }? = nil
		if statusStyle ~= nil then
			local dressing: { [string]: React.ReactNode } = {}
			dressing.gradient = e("UIGradient", { Color = statusStyle.textGradient })
			rowDressing = dressing
		end
		for index, row in rows do
			local statId = row.id
			rowNodes[statId] = e("TextButton", {
				AutoButtonColor = false,
				Text = "",
				[React.Event.MouseEnter] = function()
					setHoveredStat(statId)
				end,
				[React.Event.MouseLeave] = function()
					setHoveredStat(NO_STAT)
				end,
				LayoutOrder = index,
				BackgroundTransparency = 1,
				Font = Tokens.font.bold,
				TextScaled = true,
				RichText = true,
				TextColor3 = STAT_ROW_COLOR,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = TEXT_ZINDEX,
			}, {
				text = e("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Font = Tokens.font.bold,
					TextScaled = true,
					RichText = true,
					TextColor3 = STAT_ROW_COLOR,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = if obscured then StatusDisplay.obscure(statRowText(row)) else statRowText(row),
					ZIndex = TEXT_ZINDEX,
				}, rowDressing),
			})

			-- The tooltip for the row under the pointer, if that stat has copy written for it.
			if statId == hoveredStat then
				local description = StatDisplay.description(statId)
				if description ~= nil then
					children.tooltip = e("TextLabel", {
						Position = UDim2.fromScale(
							TOOLTIP_X,
							SECONDARY_REGION.pos.Y.Scale
								+ (index - 1) * SECONDARY_ROW_HEIGHT * SECONDARY_REGION.size.Y.Scale
						),
						Size = UDim2.fromScale(TOOLTIP_WIDTH, TOOLTIP_HEIGHT),
						BackgroundColor3 = TOOLTIP_BACKGROUND,
						BackgroundTransparency = TOOLTIP_TRANSPARENCY,
						BorderSizePixel = 0,
						Font = Tokens.font.body,
						TextScaled = true,
						TextWrapped = true,
						TextColor3 = Tokens.color.text,
						Text = description,
						ZIndex = TOOLTIP_ZINDEX,
					}, {
						padding = e("UIPadding", {
							PaddingLeft = UDim.new(0, Tokens.space.xs),
							PaddingRight = UDim.new(0, Tokens.space.xs),
							PaddingTop = UDim.new(0, Tokens.space.xs),
							PaddingBottom = UDim.new(0, Tokens.space.xs),
						}),
						corner = e("UICorner", { CornerRadius = UDim.new(0, Tokens.radius.sm) }),
					})
				end
			end
		end
		children.secondaryStats = e("Frame", {
			Position = SECONDARY_REGION.pos,
			Size = SECONDARY_REGION.size,
			BackgroundTransparency = 1,
			ZIndex = TEXT_ZINDEX,
		}, rowNodes)
	end

	if item.description ~= nil and item.description ~= "" then
		-- Under a status the prose is obscured, recoloured, and wears the status gradient — the authored
		-- ItemDescription differs from the ordinary one in all three ways at once.
		local description = if obscured then StatusDisplay.obscure(item.description) else item.description
		local descriptionColor = if statusStyle ~= nil then statusStyle.descriptionColor else Tokens.color.text
		children.description =
			line(DESCRIPTION_REGION, descriptionColor, Enum.TextXAlignment.Center, description, statusStyle)
	end

	-- The authored row hides entirely when the item has no requirement, and turns red when the viewer
	-- cannot meet it.
	local requiredLevel = item.requiredLevel
	if requiredLevel ~= nil then
		local playerLevel = props.playerLevel
		local unmet = playerLevel ~= nil and playerLevel < requiredLevel
		children.level = line(
			LEVEL_REGION,
			if unmet then LEVEL_UNMET_COLOR else LEVEL_MET_COLOR,
			Enum.TextXAlignment.Center,
			`REQUIRED LEVEL: {requiredLevel}`
		)
	end

	-- The status line. The authored game treats BIND ON EQUIP as the DEFAULT and rotbound as the
	-- exception (`"ITEM IS " .. (item.Rotbound and "ROTBOUND" or "BIND ON EQUIP")`), so every item gets
	-- this line; rotbound is not modelled, so the exception never fires yet.
	local statusColor = if statusStyle ~= nil then statusStyle.statusColor else STATUS_COLOR
	children.status =
		line(STATUS_REGION, statusColor, Enum.TextXAlignment.Center, StatusDisplay.label(props.status), statusStyle)

	-- The status overlay. Its GRADIENT is what shapes it: opaque only at the card's top and bottom edges
	-- and clear between, so the status bleeds in from the frame rather than washing the card flat.
	if statusStyle ~= nil then
		children.statusWash = e("ImageLabel", {
			Position = RARITY_WASH_REGION.pos,
			Size = RARITY_WASH_REGION.size,
			BackgroundTransparency = 1,
			Image = UIAssets.itemCard.rarityBar,
			ImageColor3 = statusStyle.overlayTint,
			ImageTransparency = statusStyle.overlayTransparency,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = STATUS_ZINDEX,
		}, {
			bleed = e("UIGradient", {
				Color = statusStyle.overlayGradient,
				Transparency = statusStyle.overlayFalloff,
				Rotation = statusStyle.overlayRotation,
			}),
		})
	end

	-- The primary line, for the one case the data supports: a stack's amount against its ceiling.
	-- Weapons and armour keep it reserved and blank until damage/defense exist (see the header).
	local stackMax = item.stackMax
	local quantity = item.quantity
	if stackMax ~= nil and quantity ~= nil then
		local full = quantity >= stackMax
		children.stat = line(
			STAT_REGION,
			if full then STAT_FULL_COLOR else STAT_COLOR,
			Enum.TextXAlignment.Left,
			`AMOUNT: {quantity}/{stackMax}`
		)
	end

	if props.pinned == true then
		children.actions = e(ItemActions, {
			handlers = props.actions,
			onActionTaken = props.onActionTaken,
			equipLabel = props.equipLabel,
		})
	end

	-- Centred in whatever container it is given; the aspect constraint fits it inside.
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

return ItemDetail
