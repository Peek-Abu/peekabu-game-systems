--!strict
--[=[
	ToonStatRows.story: each employee's five stats on a dark plate, at desktop and phone row sizes. In Studio's edit
	mode (UI Labs).

	@class ToonStatRows.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonStatRows = require(Toon.ToonStatRows)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryViewModel)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Phone = false },
}, function(props)
	local phone = props.controls.Phone
	local row = if phone then 22 else 50
	local width = if phone then 260 else 560
	local nodes: { [string]: React.ReactNode } = {}
	for index, name in { "Pippa", "Cappy", "Prickles" } do
		nodes[name] = e(ToonStatRows, {
			rows = InventoryViewModel.stats(name),
			row = row,
			barX = if phone then 100 else 200,
			textSize = if phone then 12 else 22,
			position = UDim2.fromOffset(30 + (index - 1) * (width + 40), 30),
			size = UDim2.fromOffset(width, row * 5),
		})
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("2B1856"),
	}, nodes)
end)
