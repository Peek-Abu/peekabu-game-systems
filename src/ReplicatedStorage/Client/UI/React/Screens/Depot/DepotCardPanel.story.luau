--!strict
--[=[
	DepotCardPanel.story: the placeholder travel card in Studio's edit mode (UI Labs).

	@class DepotCardPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local DepotCardPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardPanel)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Arrival = true,
	},
}, function(props)
	local arrival = props.controls.Arrival
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
	}, {
		card = e(DepotCardPanel, {
			kind = if arrival then "arrival" else "drive",
			title = if arrival then "Harlow & Finch Ltd." else "On the road",
			body = if arrival
				then "Clear the office before the sale. Clear 350 of trash. The bank says the building is empty."
				else "Heading to Harlow & Finch Ltd.",
		}),
	})
end)
