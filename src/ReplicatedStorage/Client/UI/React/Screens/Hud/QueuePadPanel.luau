--!strict
--[=[
	QueuePadPanel: the placeholder pad panel: players aboard, the countdown and a Depart-now button.
	Presentational only (props in, a callback out). Plain on purpose: each game's final pad UI is designed
	and approved in Figma first, and replaces this.

	@class QueuePadPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Button = require(ReplicatedStorage.Client.UI.React.Primitives.Button)
local Panel = require(ReplicatedStorage.Client.UI.React.Primitives.Panel)

local e = React.createElement

export type QueuePadPanelProps = {
	aboard: number,
	capacity: number,
	-- Whole seconds until departure, or nil while departing.
	secondsLeft: number?,
	departing: boolean,
	onDepart: () -> (),
}

local WIDTH = 240

local function statusText(props: QueuePadPanelProps): string
	if props.departing then
		return "Departing…"
	end
	local seconds = props.secondsLeft
	if seconds == nil then
		return "Waiting"
	end
	return `Leaving in {seconds}s`
end

local function QueuePadPanel(props: QueuePadPanelProps): React.ReactNode
	-- Annotated so the mixed children widen to ReactNode (Panel's `children` type), as DebugPanelScreen does.
	local body: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Tokens.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		status = e("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, Tokens.textSize.lg + Tokens.space.xs),
			BackgroundTransparency = 1,
			Font = Tokens.font.medium,
			TextSize = Tokens.textSize.lg,
			TextColor3 = Tokens.color.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = statusText(props),
		}),
		depart = e(Button, {
			text = "Depart now",
			variant = "primary",
			disabled = props.departing,
			onActivated = props.onDepart,
			layoutOrder = 2,
		}),
	}
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -Tokens.space.xxl * 3),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		panel = e(Panel, { title = `{props.aboard}/{props.capacity} aboard`, children = body }),
	})
end

return QueuePadPanel
