--!strict
--[=[
	ToastStack: the toasts on screen, stacked top-centre, newest at the bottom, each drawn in its
	ToastRegistry style. Reads ToastStore; never writes.

	@class ToastStack
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local ToastRegistry = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastRegistry)
local ToastStore = require(ReplicatedStorage.Client.Features.Toast.State.ToastStore)

local e = React.createElement

local WIDTH = 360

local function ToastStack(): React.ReactNode
	local toasts = ReactCharm.useAtom(ToastStore.toasts)
	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Tokens.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, toast in toasts do
		local style = ToastRegistry.get(toast.style) or ToastRegistry.get("info")
		if style ~= nil then
			children[`toast{toast.id}`] = e("TextLabel", {
				LayoutOrder = index,
				Size = UDim2.fromOffset(WIDTH, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = style.background,
				TextColor3 = style.text,
				Font = style.font,
				TextSize = Tokens.textSize.xl,
				TextWrapped = true,
				Text = toast.text,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, Tokens.radius.md) }),
				stroke = e("UIStroke", {
					Color = style.accent,
					Thickness = Tokens.stroke.thick,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				padding = e("UIPadding", {
					PaddingTop = UDim.new(0, Tokens.space.md),
					PaddingBottom = UDim.new(0, Tokens.space.md),
					PaddingLeft = UDim.new(0, Tokens.space.lg),
					PaddingRight = UDim.new(0, Tokens.space.lg),
				}),
			})
		end
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Tokens.space.xxl * 3),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, children)
end

return ToastStack
