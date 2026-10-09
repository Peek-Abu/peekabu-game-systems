--!strict
--[=[
	DebugPanelScreen: a throwaway placeholder screen the debug `PanelA` scene mounts, so the SceneHost
	render path is observable BEFORE the real Inventory panel exists — the same harness role UIDebugScenes
	plays for suppression. Pushing PanelA now actually mounts a panel on the `Panel` layer; popping it
	unmounts it. Replaced by the real inventory screen; carries no logic.

	@class DebugPanelScreen
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Panel = require(ReplicatedStorage.Client.UI.React.Primitives.Panel)

local e = React.createElement

--[=[
	@return React.ReactNode
]=]
local function DebugPanelScreen(): React.ReactNode
	local body: { [string]: React.ReactNode } = {
		text = e("TextLabel", {
			Size = UDim2.new(1, 0, 0, Tokens.textSize.md * 3),
			BackgroundTransparency = 1,
			Font = Tokens.font.body,
			TextSize = Tokens.textSize.md,
			TextWrapped = true,
			TextColor3 = Tokens.color.textMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Rendered by SceneHost from the scene stack. Push PanelB over it, or Escape to pop.",
		}),
	}

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		-- Centre a fixed-width panel on the layer.
		center = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(380, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, {
			panel = e(Panel, { title = "Debug Panel A", children = body }),
		}),
	})
end

return DebugPanelScreen
