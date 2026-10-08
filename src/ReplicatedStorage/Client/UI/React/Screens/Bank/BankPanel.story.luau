--!strict
--[=[
	BankPanel.story: both containers side by side, with transfers working against a LOCAL stand-in for
	the server, in Studio's edit mode.

	The panel takes its four transfer requests as a prop precisely so this can exist: the real ones go
	through ByteNet, which has nothing to talk to without a running server. `StoryFixtures.localBank`
	edits the seeded atoms instead, so right-click and drag both move items between the two sides here.

	What it CANNOT show is a refusal — neither container's capacity is modelled by the stand-in, and a
	full bank or a breached per-kind inventory cap is exactly the case only the real server decides.

	@class BankPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local BankPanel = require(ReplicatedStorage.Client.UI.React.Screens.Bank.BankPanel)
local StoryFixtures = require(ReplicatedStorage.Client.UI.React.StoryFixtures)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		BagCount = 18,
		BankCount = 12,
	},
}, function(props)
	-- Seed ONCE per control change, not per render: transfers edit these same atoms, so reseeding every
	-- render would undo whatever you just moved.
	local bagCount: number = props.controls.BagCount
	local bankCount: number = props.controls.BankCount
	local actions = React.useMemo(function()
		StoryFixtures.seedInventory(bagCount)
		StoryFixtures.seedBank(bankCount)
		return StoryFixtures.localBank()
	end, { bagCount, bankCount })

	return e(BankPanel, { actions = actions })
end)
