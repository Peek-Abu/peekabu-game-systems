--!strict
--[=[
	DepotHubPanel.story: the V1 hub HUD at the desktop design (1920x1080) or the phone design (844x390), idle or aboard a
	truck (the Next shift card's two states), with the gift ready or counting down. In Studio's edit mode (UI Labs).

	@class DepotHubPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local DepotHubPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubPanel)
local DepotHubViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubViewModel)
local DepotPadViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadViewModel)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Phone = false,
		Aboard = false,
		GiftReady = true,
		Xp = 45,
	},
}, function(props)
	local controls = props.controls
	local phone = controls.Phone == true
	local function noop() end
	local pad = DepotPadViewModel.pad({
		members = { 1, 2 },
		capacity = 4,
		destination = "shift",
		endsAt = 112,
		departing = false,
	}, 1, { [2] = "Biscuit" }, 2, 100, phone)
	local now = 20000 * 86400 + 3600
	local daily = if controls.GiftReady then { lastDay = 19999, streak = 2 } else { lastDay = 20000, streak = 3 }
	local hub = e(DepotHubPanel, {
		phone = phone,
		profile = DepotHubViewModel.profile("Pippa", { xp = controls.Xp, prevXp = controls.Xp }),
		credits = "1,240",
		gift = DepotHubViewModel.gift(daily, now),
		tonight = DepotHubViewModel.tonight("harlow-finch-1"),
		cta = DepotPadViewModel.cta(if controls.Aboard then pad else nil, 2),
		newJobs = true,
		onJobs = noop,
		onLocker = noop,
		onGuide = noop,
		onSettings = noop,
		onGift = noop,
		onGo = noop,
	})
	local design = if phone then Vector2.new(844, 390) else Vector2.new(1920, 1080)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("C9A46A"),
	}, {
		screen = e("Frame", {
			Size = UDim2.fromOffset(design.X, design.Y),
			BackgroundTransparency = 1,
		}, { hub = hub }),
	})
end)
