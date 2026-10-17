--!strict
--[=[
	ToonPanel.story: A cream panel, a modal whose grape header melts into drips with a close button, a dark card with a goo pool, and the pop-in plus wipe (Replay plays it again). In Studio's edit mode (UI Labs).

	@class ToonPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonPanel = require(Toon.ToonPanel)
local ToonText = require(Toon.ToonText)

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
	controls = { Replay = 0 },
}, function(props)
	local controls = props.controls
	local function noop() end
	local nodes: { [string]: React.ReactNode } = {}
	local text: { [string]: React.ReactNode } = {}
	text.body = e(ToonText, {
		text = "Harlow & Finch · 4th floor offices",
		font = "body",
		textSize = 24,
		position = UDim2.fromOffset(28, 30),
		size = UDim2.fromOffset(400, 30),
	})
	nodes.plain = e(ToonPanel, {
		size = Vector2.new(460, 200),
		position = UDim2.fromOffset(40, 40),
		children = text,
	})
	nodes.modal = e(ToonPanel, {
		size = Vector2.new(980, 420),
		position = UDim2.fromOffset(560, 80),
		header = {
			title = "JOBS",
			subtitle = "Morrow & Morrow Clearance · tonight's contracts",
			icon = "jobs",
			goo = true,
		},
		onClose = noop,
	})
	nodes.locked = e(ToonPanel, {
		hue = "night",
		size = Vector2.new(320, 300),
		position = UDim2.fromOffset(40, 300),
		goo = { kind = "pool" },
	})
	nodes["popped" .. tostring(controls.Replay)] = e(ToonPanel, {
		size = Vector2.new(420, 220),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromOffset(780, 700),
		pop = true,
		wipe = true,
	})
	return backdrop(nodes)
end)
