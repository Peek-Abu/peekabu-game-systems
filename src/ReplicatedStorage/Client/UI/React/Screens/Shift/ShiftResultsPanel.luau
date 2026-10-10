--!strict
--[=[
	ShiftResultsPanel: the M1 placeholder performance review (spec §3 step 7): a centred Panel of plain lines
	and two vote buttons, the player's own choice highlighted. Presentational: it draws the ResultsView it is
	given and reports a click through `onVote`.

	@class ShiftResultsPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Button = require(ReplicatedStorage.Client.UI.React.Primitives.Button)
local Panel = require(ReplicatedStorage.Client.UI.React.Primitives.Panel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement

local WIDTH = 440

export type ShiftResultsPanelProps = {
	view: ShiftHudViewModel.ResultsView,
	-- The local player's vote; a plain string because a singleton union widens across useAtom.
	myVote: string?,
	onVote: (choice: ShiftTypes.Vote) -> (),
}

local function text(order: number, value: string, color: Color3): React.ReactNode
	return e("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Tokens.font.body,
		TextSize = Tokens.textSize.lg,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = value,
	})
end

local function ShiftResultsPanel(props: ShiftResultsPanelProps): React.ReactNode
	local view = props.view
	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Tokens.space.xs),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, value in view.lines do
		children[`line{index}`] = text(index, value, Tokens.color.text)
	end
	local after = #view.lines
	children.countdown = text(after + 1, view.countdown, Tokens.color.textMuted)
	children.buttons = e("Frame", {
		LayoutOrder = after + 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Tokens.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		another = e(Button, {
			text = view.another,
			selected = props.myVote == "another",
			layoutOrder = 1,
			onActivated = function()
				props.onVote("another")
			end,
		}),
		depot = e(Button, {
			text = view.depot,
			selected = props.myVote == "depot",
			layoutOrder = 2,
			onActivated = function()
				props.onVote("depot")
			end,
		}),
	})
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		panel = e(Panel, { title = view.title, width = WIDTH, children = children }),
	})
end

return ShiftResultsPanel
