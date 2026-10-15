--!strict
--[=[
	CargoWorld.story: the on-shift cargo signs (Figma World UI 2b) over the dark office, in Studio's edit mode (UI
	Labs). Price tags for a salvage item, a trash item, the longest catalog name and the fish tank after `Impacts` drops
	(0 FRAGILE, 1 CRACKED −50%, 2+ CRACKED −75%), a grimy valuable at `Clean` (0..1: "$???" until 0.65, then appraised,
	its stamp popping while `Fresh` is on) beside a spotless Gold-trim monitor, and the two load floaters (`Fade` 0..1 previews the fade). Drawn through WorldBillboard as on a pixel-sized shell, so the
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
local CargoLoadFloater = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoLoadFloater)
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

-- A grimy valuable's tag: a monitor of base `base` at cleanliness `clean`, appraised past the threshold.
local function grimyTag(order: number, name: string, base: number, clean: number, fresh: boolean): React.ReactNode
	local appraised = clean >= CargoConstants.APPRAISE_AT
	local factor = CargoConstants.GRIME_FLOOR + (1 - CargoConstants.GRIME_FLOOR) * clean
	local view = CargoWorldViewModel.priceTag({
		[KEYS.name] = name,
		[KEYS.category] = "salvage",
		[KEYS.value] = base * factor,
		[KEYS.fragile] = true,
		[KEYS.impacts] = 0,
		[KEYS.hidden] = false,
		[KEYS.grimy] = true,
		[KEYS.clean] = clean,
		[KEYS.appraised] = appraised,
		[KEYS.appraisedAt] = if appraised then (if fresh then 100 else 0) else nil,
	}, 100)
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

-- A load floater at fade `fade` (a fixed binding: the story needs no hook).
local function floaterSign(order: number, text: string, tone: "clearance" | "bonus", fade: number): React.ReactNode
	local size = CargoConstants.FLOATER_PX
	local binding = React.createBinding(fade)
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
	}, {
		billboard = e(WorldBillboard, { design = size, sizing = "pixels" }, {
			floater = e(CargoLoadFloater, {
				view = CargoWorldViewModel.floater({ text = text, tone = tone }),
				fade = binding,
			}),
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
		Fade = 0,
		Clean = 0.4,
		Fresh = true,
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
			coffeeMachine = priceTag(1, "coffeeMachine", 0),
			bag = priceTag(2, "rubbishBag", 0),
			plaque = priceTag(3, "plaque", 0),
			monitor = priceTag(4, "monitor", 0),
			fishTank = priceTag(5, "fishTank", impacts),
		}),
		grime = row(2, {
			grimy = grimyTag(1, "Monitor", 100, math.clamp(props.controls.Clean, 0, 1), props.controls.Fresh == true),
			spotless = grimyTag(2, "Gold-trim monitor", 250, 1, false),
		}),
		floaters = row(3, {
			clearance = floaterSign(1, "+15", "clearance", math.clamp(props.controls.Fade, 0, 1)),
			bonus = floaterSign(2, "+40", "bonus", math.clamp(props.controls.Fade, 0, 1)),
		}),
	})
end)
