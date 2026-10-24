--!strict
--[=[
	RevealScreen.story: a reveal for any catalogue id (a Legendary skin, an Uncommon skin, a sticker pack, a hire from
	the pick or from the Shop), at desktop or phone size. In Studio's edit mode (UI Labs); the 3D previews need the
	employee art in ReplicatedStorage.Assets (the hub place).

	@class RevealScreen.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local RevealScreen = require(script.Parent.RevealScreen)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Item = "Pippa.BubbleBuddy", Source = "shop", Phone = false },
}, function(props)
	local phone = props.controls.Phone == true
	return e(RevealScreen, {
		reveal = { ids = { props.controls.Item }, source = props.controls.Source },
		phone = phone,
		viewport = if phone then Vector2.new(844, 390) else Vector2.new(1920, 1080),
	})
end)
