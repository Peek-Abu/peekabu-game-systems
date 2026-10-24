--!strict
--[=[
	InventoryScreen.story: the Inventory with fixed data (owns Prickles, Lavender Specs and Gloom-Touched; wears
	Lavender Specs): the Crew tab, or an employee's page, at desktop or phone size. In Studio's edit mode (UI Labs);
	the 3D previews need the employee art in ReplicatedStorage.Assets (the hub place).

	@class InventoryScreen.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local InventoryScreen = require(script.Parent.InventoryScreen)

local e = React.createElement

local OWNED = { Prickles = true, ["Pippa.OwnerSpecial"] = true, ["Pippa.GloomTouched"] = true }

local function owns(id: string): boolean
	local item = CosmeticRegistry.get(id)
	return item ~= nil and (item.source == "default" or OWNED[id] == true)
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Employee = "", Phone = false },
}, function(props)
	local loadout = CosmeticConstants.defaultLoadout()
	loadout.picked = true
	loadout.looks.Pippa = { skin = "Pippa.OwnerSpecial", style = 1, idle = "Pippa.Classic", wheel = { "", "", "", "" } }
	local phone = props.controls.Phone == true
	local employee = props.controls.Employee
	return e(InventoryScreen, {
		preview = { loadout = loadout, owns = owns, credits = 3140, gleam = 640 },
		phone = phone,
		viewport = if phone then Vector2.new(844, 390) else Vector2.new(1920, 1080),
		employee = if employee ~= "" then employee else nil,
	})
end)
