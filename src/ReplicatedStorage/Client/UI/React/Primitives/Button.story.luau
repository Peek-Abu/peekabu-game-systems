--!strict
--[=[
	Button.story: every Button variant and state side by side, in Studio's edit mode (UI Labs). The
	reference for writing a story: controls in, a React tree out, no Play session needed.

	@class Button.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Button = require(ReplicatedStorage.Client.UI.React.Primitives.Button)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Text = "Confirm",
		Disabled = false,
	},
}, function(props)
	local controls = props.controls
	local function noop() end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
	}, {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Tokens.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		primary = e(Button, {
			text = controls.Text,
			variant = "primary",
			disabled = controls.Disabled,
			onActivated = noop,
			layoutOrder = 1,
		}),
		secondary = e(Button, {
			text = controls.Text,
			disabled = controls.Disabled,
			onActivated = noop,
			layoutOrder = 2,
		}),
		ghost = e(Button, {
			text = controls.Text,
			variant = "ghost",
			disabled = controls.Disabled,
			onActivated = noop,
			layoutOrder = 3,
		}),
		selected = e(Button, {
			text = controls.Text,
			selected = true,
			disabled = controls.Disabled,
			onActivated = noop,
			layoutOrder = 4,
		}),
	})
end)
