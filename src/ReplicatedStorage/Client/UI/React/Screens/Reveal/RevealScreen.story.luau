--!strict
--[=[
	RevealScreen.story: a reveal for any catalogue id (a Legendary skin, an Uncommon skin, a sticker pack, a hire from
	the pick or from the Shop), or a Robux purchase (Purchase: gleam, pass or coffee; Key and Amount), at desktop or phone size. In Studio's edit mode (UI Labs); the 3D previews need the
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
	controls = {
		Item = "Pippa.BubbleBuddy",
		Source = "shop",
		Purchase = "",
		Key = "gleam880",
		Amount = 880,
		Phone = false,
	},
}, function(props)
	local phone = props.controls.Phone == true
	local kind = props.controls.Purchase
	local purchase = if kind == "gleam"
			or kind == "pass"
			or kind == "coffee"
		then { kind = kind, key = props.controls.Key, amount = props.controls.Amount }
		else nil
	return e(RevealScreen, {
		reveal = if purchase ~= nil
			then { ids = {}, source = "robux", purchase = purchase }
			else { ids = { props.controls.Item }, source = props.controls.Source },
		phone = phone,
		viewport = if phone then Vector2.new(844, 390) else Vector2.new(1920, 1080),
	})
end)
