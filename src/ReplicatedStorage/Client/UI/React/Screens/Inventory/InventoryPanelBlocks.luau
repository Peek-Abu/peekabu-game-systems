--!strict
--[=[
	InventoryPanelBlocks: the Inventory character page's props and its layout pieces (body text, a full-size group, a
	padded top-to-bottom stack, a fixed-height block in a stack), shared by InventoryCharacterPanel and its columns
	(InventoryItemGrid, InventoryItemDetail, InventoryAboutColumns). Split out of InventoryCharacterPanel.
	Presentational (exempt).

	@class InventoryPanelBlocks
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.InventoryViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

export type InventoryCharacterPanelProps = {
	employee: string,
	tab: VM.PageTab,
	layout: VM.Layout,
	loadout: CosmeticTypes.Loadout,
	owns: (id: string) -> boolean,
	-- The selected item (nil = the worn one).
	selected: string?,
	-- When this page was opened from the crew: the hero reacts to it (ToonViewport `react`).
	openedAt: number?,
	onSelect: (id: string) -> (),
	onWear: (change: CosmeticTypes.Change) -> (),
	-- Opens the item's Shop page.
	onShop: (id: string) -> (),
	-- The shown item was New! and has now been looked at.
	onSeen: (ids: { string }) -> (),
}

export type Nodes = { [string]: React.ReactNode }

local function body(value: string, size: number, color: Color3?): React.ReactNode
	return e(ToonText, {
		text = value,
		font = "body",
		color = color or COLOR.ink,
		textSize = size,
		size = UDim2.fromScale(1, 1),
		wrapped = true,
		alignY = "top",
	})
end

local function group(children: Nodes): React.ReactNode
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children)
end

-- A column of blocks laid out top to bottom.
local function stack(children: Nodes, padding: number, inset: number): React.ReactNode
	local nodes: Nodes = {
		list = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, padding) }),
		pad = e("UIPadding", {
			PaddingLeft = UDim.new(0, inset),
			PaddingRight = UDim.new(0, inset),
			PaddingTop = UDim.new(0, inset),
		}),
	}
	for key, node in children do
		nodes[key] = node
	end
	return group(nodes)
end

-- A block in a stack: a fixed-height frame holding one node.
local function block(height: number, order: number, node: React.ReactNode): React.ReactNode
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, { node = node })
end

return {
	body = body,
	group = group,
	stack = stack,
	block = block,
}
