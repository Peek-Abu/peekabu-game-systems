--!strict
--[=[
	DepotCardPanel: the placeholder travel card: a kicker ("ON THE ROAD" / "ARRIVAL"), a title and a line of
	text, centred on screen. Presentational only (props in). Plain on purpose: the final drive and arrival
	cards are designed and approved in Figma first (Cleanup Crew spec §7 "UI approval") and replace this.

	@class DepotCardPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Panel = require(ReplicatedStorage.Client.UI.React.Primitives.Panel)

local e = React.createElement

export type DepotCardPanelProps = {
	kind: string,
	title: string,
	body: string,
}

local WIDTH = 420
local KICKER: { [string]: string } = {
	drive = "ON THE ROAD",
	arrival = "ARRIVAL",
}

local function line(order: number, text: string, size: number, color: Color3, font: Enum.Font): React.ReactNode
	return e("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = font,
		TextSize = size,
		TextColor3 = color,
		TextWrapped = true,
		RichText = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
	})
end

local function DepotCardPanel(props: DepotCardPanelProps): React.ReactNode
	-- Annotated up front (the ShiftHudPanel pattern): Panel takes `{ [string]: React.ReactNode }`, and an
	-- inline literal is inferred with exact element types that do not fit it.
	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Tokens.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		kicker = line(
			1,
			KICKER[props.kind] or string.upper(props.kind),
			Tokens.textSize.sm,
			Tokens.color.accent,
			Tokens.font.bold
		),
		title = line(2, props.title, Tokens.textSize.xxl, Tokens.color.text, Tokens.font.bold),
		body = line(3, props.body, Tokens.textSize.lg, Tokens.color.textMuted, Tokens.font.body),
	}
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		panel = e(Panel, { children = children }),
	})
end

return DepotCardPanel
