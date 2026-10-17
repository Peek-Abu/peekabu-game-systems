--!strict
--[=[
	ToonText.story: Display text in every meaning (gold Gleam, mint gain, coral time, grape Gloom, white labels) and body text. In Studio's edit mode (UI Labs).

	@class ToonText.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local function backdrop(children: { [string]: React.ReactNode }): React.ReactNode
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("2B1856"),
	}, children)
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Size = 72 },
}, function(props)
	local controls = props.controls
	local nodes: { [string]: React.ReactNode } = {}
	type Sample = { text: string, meaning: UIToonConstants.Meaning }
	local samples: { Sample } = {
		{ text = "CONTRACT MET!", meaning = "gold" },
		{ text = "+36", meaning = "mint" },
		{ text = "4:27", meaning = "coral" },
		{ text = "312", meaning = "grape" },
		{ text = "FIND A TRUCK", meaning = "white" },
	}
	for index, sample in samples do
		nodes["sample" .. index] = e(ToonText, {
			text = sample.text,
			meaning = sample.meaning,
			textSize = controls.Size,
			position = UDim2.fromOffset(60, 30 + (index - 1) * (controls.Size + 24)),
			size = UDim2.fromOffset(900, controls.Size + 16),
		})
	end
	nodes.body = e(ToonText, {
		text = "Harlow & Finch · 4th floor offices",
		font = "body",
		color = Color3.new(1, 1, 1),
		textSize = 28,
		position = UDim2.fromOffset(60, 40 + 5 * (controls.Size + 24)),
		size = UDim2.fromOffset(900, 40),
	})
	return backdrop(nodes)
end)
