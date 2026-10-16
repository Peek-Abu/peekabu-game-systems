--!strict
--[=[
	ShiftHotbar: the hotbar inventory on paper (docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md §4).
	Five cream index cards in a row, each with its key number in the corner: slot 1 the vacuum (its drawing and its
	canister), slots 2-5 the item slots (the item's own art in a little viewport and its tag: "$???" until appraised,
	its value after, "+N" for trash, in red for a FRAGILE item; its name too when the card is big enough). The cards'
	measurements are ShiftHotbarViewModel.metrics. The chosen card is lifted and
	pinned; a big item's card is stamped HANDS FULL and the other cards fade while it locks them. Tapping or clicking a
	card asks for that slot (`onSelect`). Presentational: it draws the HotbarView it is given.

	@class ShiftHotbar
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ArtKitRegistry = require(ReplicatedStorage.Shared.Features.Art.Data.ArtKitRegistry)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperPropIcon = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperPropIcon)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftHotbarViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHotbarViewModel)

local e = React.createElement
local C = UIPaperConstants.COLOR

export type Props = {
	view: ShiftHotbarViewModel.HotbarView,
	phone: boolean,
	position: UDim2,
	anchor: Vector2,
	onSelect: ((slot: number) -> ())?,
}

-- A locked hotbar fades the cards it locks this much.
local LOCKED_FADE = 0.55

-- The item's art template (the art kit's cargo model), or nil while it has none.
local function templateOf(kind: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local crew = if assets ~= nil then assets:FindFirstChild("CleanupCrew") else nil
	local kits = if crew ~= nil then crew:FindFirstChild("ArtKits") else nil
	local kit = if kits ~= nil then kits:FindFirstChild(ArtKitRegistry.DEFAULT_KIT) else nil
	local cargo = if kit ~= nil then kit:FindFirstChild("cargo") else nil
	local model = if cargo ~= nil then cargo:FindFirstChild(kind) else nil
	return if model ~= nil and model:IsA("Model") then model else nil
end

-- The item's art in a small viewport, seen from its front (the templates face -Z) a little above and to the side. The
-- viewport is filled when it mounts (a callback ref, rebuilt when the kind changes); its contents go with it.
local function ItemIcon(props: { kind: string, size: number }): React.ReactNode
	local attach = React.useCallback(function(frame: ViewportFrame?)
		if frame == nil then
			return
		end
		frame:ClearAllChildren()
		local template = templateOf(props.kind)
		if template == nil then
			return
		end
		local model = template:Clone()
		model:PivotTo(CFrame.identity)
		local box, extent = model:GetBoundingBox()
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		local radius = math.max(extent.Magnitude / 2, 0.1)
		local distance = radius / math.tan(math.rad(camera.FieldOfView / 2))
		camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0.55, 0.5, -0.65).Unit * distance, box.Position)
		model.Parent = frame
		camera.Parent = frame
		frame.CurrentCamera = camera
	end, { props.kind })
	return e("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(props.size, props.size),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 250, 235),
		LightDirection = Vector3.new(-0.4, -1, 0.6),
		ref = attach,
	})
end

type CardProps = {
	slot: ShiftHotbarViewModel.SlotView,
	phone: boolean,
	locked: boolean,
	index: number,
	onSelect: ((slot: number) -> ())?,
}

local function Card(props: CardProps): React.ReactNode
	local slot = props.slot
	local size = ShiftHotbarViewModel.metrics(props.phone)
	-- Every card but the big item's own fades while a big item locks the hotbar.
	local faded = props.locked and not slot.locked
	local fade = if faded then LOCKED_FADE else 0
	local inner = size.width - 2 * size.padding
	local content: { [string]: React.ReactNode } = {
		key = e(PaperLabel, {
			text = slot.key,
			role = "heading",
			size = size.key,
			color = if slot.selected then C.stamp else C.ink,
			position = UDim2.fromOffset(-1, -3),
			transparency = fade,
			fit = true,
		}),
	}
	local iconTop = size.iconTop
	if slot.vacuum then
		content.icon = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, iconTop),
			Size = UDim2.fromOffset(size.icon, size.icon),
			BackgroundTransparency = 1,
		}, { art = e(PaperPropIcon, { kind = "vacuum" }) })
	elseif slot.kind ~= nil then
		content.icon = e("Frame", {
			Position = UDim2.fromOffset(0, iconTop),
			Size = UDim2.new(1, 0, 0, size.icon),
			BackgroundTransparency = 1,
		}, { art = e(ItemIcon, { kind = slot.kind, size = size.icon }) })
	end
	if size.name > 0 and slot.name ~= "" then
		content.name = e(PaperLabel, {
			text = slot.name,
			role = "body",
			size = size.name,
			align = "center",
			position = UDim2.fromOffset(0, iconTop + size.icon + 2),
			frame = UDim2.fromOffset(inner, size.name + 4),
			autoSize = false,
			wrapped = false,
			scaled = true,
			minSize = 9,
			transparency = fade,
		})
	end
	if slot.tag ~= "" then
		content.tag = e(PaperLabel, {
			text = slot.tag,
			role = "number",
			size = size.tag,
			align = "center",
			color = if slot.fragile then C.inkRed else C.ink,
			position = UDim2.new(0, 0, 1, -(size.tag + 6)),
			frame = UDim2.fromOffset(inner, size.tag + 4),
			autoSize = false,
			scaled = true,
			transparency = fade,
		})
	end
	if slot.locked then
		content.stamp = e(PaperStamp, {
			-- Two lines, so the stamp stays about a card wide at a readable size.
			text = "HANDS\nFULL",
			size = size.stamp,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			tilt = -12,
		})
	end
	local lift = if slot.selected then size.lift else 0
	local tilt = if slot.selected then 0 elseif props.index % 2 == 0 then 1.5 else -1.5
	return e("TextButton", {
		LayoutOrder = props.index,
		Size = UDim2.fromOffset(size.width, size.height + size.lift),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		[React.Event.Activated] = function()
			if props.onSelect ~= nil then
				props.onSelect(slot.slot)
			end
		end,
	}, {
		card = e(PaperSheet, {
			size = UDim2.fromOffset(size.width, size.height),
			position = UDim2.fromOffset(0, size.lift - lift),
			paper = if slot.empty then C.manila else C.cream,
			tilt = tilt,
			fastener = if slot.selected then "pin" else nil,
			shadow = slot.selected,
			padding = size.padding,
			children = content,
		}),
	})
end

local function ShiftHotbar(props: Props): React.ReactNode
	local size = ShiftHotbarViewModel.metrics(props.phone)
	local cards: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, size.gap),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
	}
	for index, slot in props.view.slots do
		cards[`slot{index}`] = e(Card, {
			slot = slot,
			phone = props.phone,
			locked = props.view.locked,
			index = index,
			onSelect = props.onSelect,
		})
	end
	local bar = ShiftHotbarViewModel.barSize(props.phone, #props.view.slots)
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = UDim2.fromOffset(bar.X, bar.Y),
		BackgroundTransparency = 1,
	}, cards)
end

return ShiftHotbar
