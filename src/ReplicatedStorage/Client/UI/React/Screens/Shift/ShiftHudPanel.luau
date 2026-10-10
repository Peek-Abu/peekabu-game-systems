--!strict
--[=[
	ShiftHudPanel: the M1 placeholder Shift HUD (spec §6.2: punch clock, clearance, bonus, canister, hands
	and pockets): a plain Panel of text lines, top left, with a large clock-out countdown when one runs.
	Presentational: it draws the HudView it is given.

	@class ShiftHudPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Panel = require(ReplicatedStorage.Client.UI.React.Primitives.Panel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement

local WIDTH = 280

export type ShiftHudPanelProps = {
	view: ShiftHudViewModel.HudView,
}

local function line(order: number, text: string, color: Color3, size: number): React.ReactNode
	return e("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Tokens.font.medium,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = text,
	})
end

local function ShiftHudPanel(props: ShiftHudPanelProps): React.ReactNode
	local view = props.view
	local body = Tokens.textSize.lg
	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Tokens.space.xs),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		timer = line(1, view.timer, Tokens.color.text, Tokens.textSize.xl),
		clearance = line(2, view.clearance, if view.quotaMet then Tokens.color.success else Tokens.color.text, body),
		bonus = line(3, view.bonus, Tokens.color.warning, body),
		canister = line(4, view.canister, Tokens.color.text, body),
		hands = line(5, view.hands, Tokens.color.textMuted, body),
		pockets = line(6, view.pockets, Tokens.color.textMuted, body),
	}
	local clockOut = view.clockOut
	if clockOut ~= nil then
		children.clockOut = line(7, clockOut, Tokens.color.danger, Tokens.textSize.xxl)
	end
	return e("Frame", {
		Position = UDim2.fromOffset(Tokens.space.lg, Tokens.space.xxl * 2),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		panel = e(Panel, { width = WIDTH, children = children }),
	})
end

return ShiftHudPanel
