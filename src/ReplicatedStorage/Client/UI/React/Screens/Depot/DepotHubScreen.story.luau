--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Screen = require(script.Parent.DepotHubScreen)
return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Gear = false, Settings = false, Phone = false, Portrait = false },
}, function(props)
	return React.createElement(Screen, {
		page = if props.controls.Settings then "settings" elseif props.controls.Gear then "gear" else "guide",
		preview = true,
		phone = props.controls.Phone or props.controls.Portrait,
		viewport = if props.controls.Portrait
			then Vector2.new(390, 844)
			elseif props.controls.Phone then Vector2.new(844, 390)
			else nil,
	})
end)
