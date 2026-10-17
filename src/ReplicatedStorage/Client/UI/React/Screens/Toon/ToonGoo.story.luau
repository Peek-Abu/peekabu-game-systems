--!strict
--[=[
	ToonGoo.story: Goo attached to components: a cap poured along a top edge and a pool on a floor, on cream and night faces at several widths. In Studio's edit mode (UI Labs).

	@class ToonGoo.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonSurface = require(Toon.ToonSurface)
local ToonGoo = require(Toon.ToonGoo)

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
	controls = { Width = 520 },
}, function(props)
	local controls = props.controls
	local nodes: { [string]: React.ReactNode } = {}
	local width = controls.Width
	local function face(kind: "cap" | "pool", hue: "cream" | "night", x: number, y: number, w: number): React.ReactNode
		local goo: { [string]: React.ReactNode } = {}
		goo.goo = e(ToonGoo, { kind = kind, width = w, radius = 26 })
		return e(ToonSurface, {
			hue = hue,
			radius = 26,
			pattern = if hue == "cream" then "sparkle" else "bubbles",
			position = UDim2.fromOffset(x, y),
			size = UDim2.fromOffset(w, 180),
			children = if kind == "cap" then goo else nil,
			overlay = if kind == "pool" then goo else nil,
		})
	end
	nodes.capCream = face("cap", "cream", 40, 40, width)
	nodes.poolNight = face("pool", "night", 40, 260, width)
	nodes.capShort = face("cap", "cream", width + 80, 40, 160)
	nodes.poolShort = face("pool", "night", width + 80, 260, 200)
	return backdrop(nodes)
end)
