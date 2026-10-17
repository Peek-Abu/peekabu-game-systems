--!strict
--[=[
	ShiftActionButton.story: the phone's action arc in Studio's edit mode (UI Labs), on an 844x390 phone frame: the big
	button (`Bank` turns VACUUM into BANK, `Ready` lights it mint, `Unavailable` steels and fades it), DROP, THROW,
	SPRINT and CROUCH (`Crouching` lights it) at their arc spots.

	@class ShiftActionButton.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ShiftActionButton = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftActionButton)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

local PHONE = Vector2.new(844, 390)

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Bank = false, Ready = false, Unavailable = false, Crouching = false },
}, function(props)
	local controls = props.controls
	local arc = ShiftHudViewModel.arcFor(math.min(PHONE.X, PHONE.Y))
	local function noop() end
	local function button(
		label: string,
		spot: ShiftHudViewModel.ArcSpot,
		large: boolean,
		ready: boolean,
		available: boolean
	)
		return e(ShiftActionButton, {
			label = label,
			spot = spot,
			large = large,
			available = available,
			ready = ready,
			onActivated = noop,
		})
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIToonConstants.shade("night").lo,
		BorderSizePixel = 0,
	}, {
		phone = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(PHONE.X, PHONE.Y),
			BackgroundColor3 = Color3.fromRGB(70, 62, 84),
			BorderSizePixel = 0,
		}, {
			primary = button(
				if controls.Bank then "BANK" else "VACUUM",
				arc.primary,
				true,
				controls.Ready,
				not controls.Unavailable
			),
			drop = button("DROP", arc.drop, false, false, true),
			throw = button("THROW", arc.throw, false, false, true),
			sprint = button("SPRINT", arc.sprint, false, false, true),
			crouch = button("CROUCH", arc.crouch, false, controls.Crouching, true),
		}),
	})
end)
