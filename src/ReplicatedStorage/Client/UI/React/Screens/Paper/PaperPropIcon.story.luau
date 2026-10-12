--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Button = require(script.Parent.PaperButton)
local Icon = require(script.Parent.PaperPropIcon)
local VM = require(script.Parent.PaperPropViewModel)
local function art(kind: VM.Kind): React.ReactNode
	return React.createElement(Icon, { kind = kind })
end
return UILabs.CreateReactStory(
	{ react = React, reactRoblox = ReactRoblox, controls = { Phone = false, Disabled = false } },
	function(props)
		local nodes: { [string]: React.ReactNode } = {}
		local size = if props.controls.Phone then Vector2.new(62, 72) else Vector2.new(86, 106)
		local kinds = { "jobs", "guide", "gear", "settings" }
		local artwork: { [string]: React.ReactNode } =
			{ jobs = art("jobs"), guide = art("guide"), gear = art("gear"), settings = art("settings") }
		for index, kind in kinds do
			local icon = artwork[kind]
			nodes[kind] = React.createElement(Button, {
				text = string.upper(kind),
				variant = "prop",
				icon = icon,
				selected = kind == "jobs",
				disabled = props.controls.Disabled,
				onActivated = function() end,
				position = UDim2.fromOffset((index - 1) * (size.X + 14), 0),
				size = UDim2.fromOffset(size.X, size.Y),
				textSize = if props.controls.Phone then 14 else 20,
			})
		end
		return React.createElement(
			"Frame",
			{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("1A1F26") },
			{
				nav = React.createElement("Frame", {
					Position = UDim2.fromOffset(40, 100),
					Size = UDim2.fromOffset(500, 150),
					BackgroundTransparency = 1,
				}, nodes),
			}
		)
	end
)
