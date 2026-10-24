--!strict
--[=[
	ToonSourceBand.story: Every footer band on a card-sized frame: price, Gloom Locker, goal, missed, later, wearing. In Studio's edit mode (UI Labs).

	@class ToonSourceBand.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonSourceBand = require(Toon.ToonSourceBand)

local e = React.createElement

local BANDS: { { kind: ToonSourceBand.Kind, text: string } } = {
	{ kind = "credits", text = "2,500" },
	{ kind = "gleam", text = "1,500" },
	{ kind = "locker", text = "Gloom Locker" },
	{ kind = "goal", text = "Clean 50 rooms" },
	{ kind = "missed", text = "Missed it" },
	{ kind = "later", text = "Coming later" },
	{ kind = "wearing", text = "Wearing" },
}

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
}, function()
	local nodes: { [string]: React.ReactNode } = {}
	for index, band in BANDS do
		nodes[band.kind] = e("Frame", {
			Position = UDim2.fromOffset(30 + (index - 1) * 200, 60),
			Size = UDim2.fromOffset(180, 240),
			BackgroundColor3 = Color3.fromHex("B48BFF"),
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 18) }),
			band = e(ToonSourceBand, { kind = band.kind, text = band.text, height = 40, radius = 18 }),
		})
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("2B1856") }, nodes)
end)
