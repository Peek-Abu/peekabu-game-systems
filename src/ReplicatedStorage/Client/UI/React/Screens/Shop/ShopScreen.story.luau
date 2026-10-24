--!strict
--[=[
	ShopScreen.story: the Shop with fixed data (1,600 Gleam, 3,000 Credits, owns Gloom-Touched Pippa): a tab, or an
	item's page, at desktop or phone size. In Studio's edit mode (UI Labs); the 3D previews need the employee art in
	ReplicatedStorage.Assets (the hub place).

	@class ShopScreen.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local ShopScreen = require(script.Parent.ShopScreen)

local e = React.createElement

local OWNED = { ["Pippa.GloomTouched"] = true, CozyPack = true }

local function owns(id: string): boolean
	local item = CosmeticRegistry.get(id)
	return item ~= nil and (item.source == "default" or OWNED[id] == true)
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Tab = "featured", Item = "", Phone = false },
}, function(props)
	local phone = props.controls.Phone == true
	local item = props.controls.Item
	return e(ShopScreen, {
		preview = { owns = owns, gleam = 1600, credits = 3000 },
		phone = phone,
		viewport = if phone then Vector2.new(844, 390) else Vector2.new(1920, 1080),
		tab = props.controls.Tab,
		item = if item ~= "" then item else nil,
	})
end)
