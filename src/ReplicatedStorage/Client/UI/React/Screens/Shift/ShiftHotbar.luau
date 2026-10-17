--!strict
--[=[
	ShiftHotbar: the hotbar inventory (docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md §4) in
	the V1 kit: five dark slots (ToonSlot) in a row, each with its key number: slot 1 the vacuum render with its Gloom
	gauge as a grape percent pill, slots 2-5 the items (the kit render where there is one, else the item's own model in
	a little viewport) with a caption pill: the worth with the Gleam coin ("???" until appraised), "+N" for trash, coral
	for a FRAGILE item. The slots' size is ShiftHotbarViewModel.metrics (the user's half-size hotbar). The chosen slot
	lifts inside the lilac ring; a big item's slot reads FULL and the others recede while it locks them. Tapping or
	clicking a slot asks for it (`onSelect`). Presentational: it draws the HotbarView it is given.

	@class ShiftHotbar
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ArtKitRegistry = require(ReplicatedStorage.Shared.Features.Art.Data.ArtKitRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonSlot = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSlot)
local ShiftHotbarViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHotbarViewModel)

local e = React.createElement

export type Props = {
	view: ShiftHotbarViewModel.HotbarView,
	phone: boolean,
	position: UDim2,
	anchor: Vector2,
	onSelect: ((slot: number) -> ())?,
}

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
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
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
	local side = size.width
	local icon: UIAssets.ToonIcon? = if slot.vacuum
		then "vacuum"
		elseif slot.kind ~= nil then ShiftHotbarViewModel.iconFor(slot.kind)
		else nil
	local kind = slot.kind
	local art: React.ReactNode = nil
	if icon == nil and kind ~= nil then
		art = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, { model = e(ItemIcon, { kind = kind, size = side }) })
	end
	local onSelect = props.onSelect
	return e("Frame", {
		LayoutOrder = props.index,
		Size = UDim2.fromOffset(side, size.height + size.lift),
		BackgroundTransparency = 1,
	}, {
		slot = e(ToonSlot, {
			side = side,
			position = UDim2.fromOffset(0, size.lift),
			hotkey = slot.key,
			icon = icon,
			art = art,
			caption = if slot.locked then "FULL" else slot.caption,
			captionIcon = if slot.coin and not slot.locked then "gleam" else nil,
			captionMeaning = if slot.vacuum then "grape" elseif slot.coin then "gold" else "white",
			captionHue = if slot.locked or slot.fragile then "coral" else nil,
			selected = slot.selected,
			-- Every slot but the big item's own recedes while a big item locks the hotbar.
			dimmed = props.locked and not slot.locked,
			onActivated = if onSelect ~= nil
				then function()
					onSelect(slot.slot)
				end
				else nil,
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
