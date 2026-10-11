--!strict
--[=[
	PaperSheet: a sheet of paper (manila by default) with an optional drop shadow, folder tab, coloured band, torn
	bottom edge and fastener (binder clip, push pin, tape or staple). Every visual is a plain Frame (no images, so it
	draws flat colours until the art pass). Presentational.

	The content region is inset by `padding` (20 by default) and by the band, and imposes no layout: like the base
	Panel, the caller's `children` bring their own UIListLayout or absolute positions.

	@class PaperSheet
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

export type Fastener = "clip" | "pin" | "tape" | "staple"

export type PaperSheetProps = {
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	paper: Color3?,
	tilt: number?,
	fastener: Fastener?,
	torn: boolean?,
	band: string?,
	bandColor: Color3?,
	tab: string?,
	shadow: boolean?,
	padding: number?,
	layoutOrder: number?,
	children: { [string]: React.ReactNode }?,
}

local COLOR = UIPaperConstants.COLOR
local BAND_HEIGHT = 26
local TAB_WIDTH = 251
local TAB_HEIGHT = 46
-- How far the paper overlaps the tab's foot, so the tab reads as part of the folder.
local TAB_TUCK = 6

local function fastenerOf(kind: Fastener?): React.ReactNode
	if kind == "clip" then
		-- A binder clip: a dark plate over the top edge with a lighter lip.
		return e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(64, 16),
			BackgroundColor3 = Color3.fromHex("3A3F47"),
			BorderSizePixel = 0,
			ZIndex = 5,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
			lip = e("Frame", {
				Position = UDim2.fromOffset(6, 3),
				Size = UDim2.new(1, -12, 0, 4),
				BackgroundColor3 = Color3.fromHex("6B717C"),
				BorderSizePixel = 0,
			}),
		})
	elseif kind == "pin" then
		return e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = COLOR.stamp,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			shine = e("Frame", {
				Position = UDim2.fromOffset(4, 3),
				Size = UDim2.fromOffset(5, 5),
				BackgroundColor3 = COLOR.cream,
				BorderSizePixel = 0,
			}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
		})
	elseif kind == "tape" then
		return e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(110, 26),
			Rotation = -2,
			BackgroundColor3 = COLOR.cream,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			ZIndex = 5,
		})
	elseif kind == "staple" then
		return e("Frame", {
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.fromOffset(26, 3),
			Rotation = -8,
			BackgroundColor3 = Color3.fromHex("9AA0A8"),
			BorderSizePixel = 0,
			ZIndex = 5,
		})
	end
	return nil
end

-- A torn bottom edge: paper-coloured squares turned 45° along the bottom, so the edge zigzags.
local function tornEdge(paper: Color3): React.ReactNode
	local teeth: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index = 1, 48 do
		teeth[`t{index}`] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(10, 10),
			Rotation = 45,
			BackgroundColor3 = paper,
			BorderSizePixel = 0,
		})
	end
	return e("Frame", {
		Position = UDim2.new(0, 0, 1, -5),
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 3,
	}, teeth)
end

-- A manila folder tab above the top-left corner; the paper covers its foot.
local function tabOf(text: string): React.ReactNode
	return e("Frame", {
		Position = UDim2.fromOffset(0, TAB_TUCK - TAB_HEIGHT),
		Size = UDim2.fromOffset(TAB_WIDTH, TAB_HEIGHT),
		BackgroundColor3 = COLOR.manilaDeep,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		label = e(PaperLabel, {
			text = text,
			role = "heading",
			size = 20,
			color = COLOR.ink,
			position = UDim2.fromOffset(16, 0),
			frame = UDim2.new(1, -32, 1, -TAB_TUCK),
			autoSize = false,
			wrapped = false,
		}),
	})
end

-- A coloured strip across the top of the paper with a cream heading.
local function bandOf(text: string, color: Color3): React.ReactNode
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, BAND_HEIGHT),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, {
		label = e(PaperLabel, {
			text = text,
			role = "heading",
			size = 20,
			color = COLOR.cream,
			position = UDim2.fromOffset(12, 0),
			frame = UDim2.new(1, -24, 1, 0),
			autoSize = false,
			wrapped = false,
		}),
	})
end

local function PaperSheet(props: PaperSheetProps): React.ReactNode
	local paper = props.paper or COLOR.manila
	local padding = props.padding or 20
	local band = props.band
	local bandHeight = if band ~= nil then BAND_HEIGHT else 0

	local content: { [string]: React.ReactNode } = {}
	if props.children ~= nil then
		for key, node in props.children do
			content[key] = node
		end
	end

	local paperChildren: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		stroke = e("UIStroke", {
			Color = COLOR.ink,
			Thickness = 1,
			Transparency = 0.8,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		content = e("Frame", {
			Position = UDim2.fromOffset(padding, padding + bandHeight),
			Size = UDim2.new(1, -2 * padding, 1, -2 * padding - bandHeight),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, content),
	}
	if band ~= nil then
		paperChildren.band = bandOf(band, props.bandColor or COLOR.stamp)
	end
	if props.torn == true then
		paperChildren.torn = tornEdge(paper)
	end

	local sheetChildren: { [string]: React.ReactNode } = {
		paper = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = paper,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, paperChildren),
		fastener = fastenerOf(props.fastener),
	}
	if props.shadow ~= false then
		sheetChildren.shadow = e("Frame", {
			Position = UDim2.fromOffset(4, 6),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.night,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) })
	end
	if props.tab ~= nil then
		sheetChildren.tab = tabOf(props.tab)
	end

	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		Rotation = props.tilt or 0,
		BackgroundTransparency = 1,
	}, sheetChildren)
end

return PaperSheet
