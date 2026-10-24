--!strict
--[=[
	CharacterPickScreen.story: the first-join pick with only the free employee owned, at desktop or phone size. In
	Studio's edit mode (UI Labs); the 3D previews need the employee art in ReplicatedStorage.Assets (the hub place).

	@class CharacterPickScreen.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CharacterPickScreen = require(script.Parent.CharacterPickScreen)

local e = React.createElement

local function owns(id: string): boolean
	local item = CosmeticRegistry.get(id)
	return item ~= nil and item.source == "default"
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Phone = false },
}, function(props)
	local phone = props.controls.Phone == true
	return e(CharacterPickScreen, {
		owns = owns,
		phone = phone,
		viewport = if phone then Vector2.new(844, 390) else Vector2.new(1920, 1080),
	})
end)
