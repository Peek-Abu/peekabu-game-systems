--!strict
--[=[
	AbilityButton.story: the ability button in Studio's edit mode (UI Labs), on an 844x390 phone frame at its arc spot and
	at its desktop spot: `Ability` picks the employee's ability, `Cooling` shows 20 of its seconds left, `Active` lights
	its effect, `Gamepad` swaps the key cap to Y.

	@class AbilityButton.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local AbilityButton = require(ReplicatedStorage.Client.UI.React.Screens.Ability.AbilityButton)
local AbilityViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Ability.AbilityViewModel)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Ability = UILabs.Choose({ "letsGo", "spotIt", "pottedPlant" }),
		Cooling = false,
		Active = false,
		Gamepad = false,
	},
}, function(props)
	local controls = props.controls
	local function view(touch: boolean): AbilityViewModel.ButtonView?
		return AbilityViewModel.button({
			abilityId = controls.Ability,
			phase = "running",
			hidden = false,
			readyAt = if controls.Cooling then 120 else 0,
			active = if controls.Active then controls.Ability else nil,
			now = 100,
			touch = touch,
			gamepad = controls.Gamepad,
			shortSide = 390,
		})
	end
	local phone = view(true)
	local desktop = view(false)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIToonConstants.shade("night").lo,
		BorderSizePixel = 0,
	}, {
		phone = e("Frame", {
			Size = UDim2.fromOffset(844, 390),
			BackgroundColor3 = UIToonConstants.shade("night").base,
			BorderSizePixel = 0,
		}, {
			button = if phone ~= nil then e(AbilityButton.AbilityButton, { view = phone }) else nil,
		}),
		desktop = if desktop ~= nil then e(AbilityButton.AbilityButton, { view = desktop }) else nil,
	})
end)
