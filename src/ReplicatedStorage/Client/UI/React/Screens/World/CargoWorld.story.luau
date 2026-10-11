--!strict
--[=[
	CargoWorld.story: the on-shift cargo signs (Figma World UI 2b) over the dark office, in Studio's edit mode (UI
	Labs). Price tags for a salvage item, a trash item, the longest catalog name and the fish tank after `Impacts` drops
	(0 FRAGILE, 1 CRACKED −50%, 2+ CRACKED −75%). Drawn through WorldBillboard as on a pixel-sized shell, so the
	scale follows this viewport (min(w/1920, h/1080), 0.6 to 1).

	@class CargoWorld.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local CargoPriceTag = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoPriceTag)
local CargoWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoWorldViewModel)
local WorldBillboard = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboard)

local e = React.createElement

local KEYS = CargoConstants.LABEL_KEYS

-- A price tag for catalog item `kind` with `impacts` drops, as its shell would draw it.
local function priceTag(order: number, kind: string, impacts: number): React.ReactNode
	local def = CargoRegistry.get(kind)
	if def == nil then
		return nil
	end
	local view = CargoWorldViewModel.priceTag({
		[KEYS.name] = def.name,
		[KEYS.category] = def.category,
		[KEYS.value] = def.value,
		[KEYS.fragile] = def.fragile,
		[KEYS.impacts] = impacts,
		[KEYS.hidden] = false,
	})
	if view == nil then
		return nil
	end
	local size = CargoConstants.LABEL_PX
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
	}, {
		billboard = e(WorldBillboard, { design = size, sizing = "pixels" }, {
			tag = e(CargoPriceTag, { view = view }),
		}),
	})
end

local function row(order: number, children: { [string]: React.ReactNode }): React.ReactNode
	local content: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 40),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for key, node in children do
		content[key] = node
	end
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, content)
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Impacts = 1,
	},
}, function(props)
	local impacts: number = math.max(0, math.floor(props.controls.Impacts))
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.office,
		BorderSizePixel = 0,
	}, {
		padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 60),
			PaddingTop = UDim.new(0, 60),
		}),
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 60),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		tags = row(1, {
			printer = priceTag(1, "printer", 0),
			bag = priceTag(2, "rubbishBag", 0),
			plaque = priceTag(3, "plaque", 0),
			monitor = priceTag(4, "monitor", 0),
			fishTank = priceTag(5, "fishTank", impacts),
		}),
	})
end)
