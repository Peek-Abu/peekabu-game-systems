--!strict
--[=[
	InventoryPanel.story: the whole panel, over a stand-in for the dimmed world, with no game running.

	The panel reads the `inventory` atom rather than taking props, so the story seeds that atom with real
	registered items — which means it exercises the real `ItemContentRegistry` → `ItemRegistry` →
	`InventoryViewModel` path, not a mock of it.

	It also seeds a couple of equipped items, so the paperdoll down the left shows both filled and empty
	cells. Use this for the plate's proportions and region alignment. The scene stack, input capture and HUD
	suppression around it still need a Play pass — this only renders the screen.

	Equipping works here, against a LOCAL stand-in for the server (`StoryFixtures.localEquipment`): the
	panel takes its actions as a prop, so right-click, the card's menu and drag-and-drop can all be tried in
	edit mode. What it cannot show is a refusal — the server's level and cap checks are not reproduced.

	@class InventoryPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local InventoryPanel = require(ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryPanel)
local StoryFixtures = require(ReplicatedStorage.Client.UI.React.StoryFixtures)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		ItemCount = 24,
	},
}, function(props)
	-- Seed ONCE per control change, not per render: now that equipping edits the same atoms, reseeding on
	-- every render would undo whatever you just equipped. Changing ItemCount is the deliberate reset.
	local count: number = props.controls.ItemCount
	local equipment = React.useMemo(function()
		StoryFixtures.seedInventory(count)
		StoryFixtures.seedEquipment()
		return StoryFixtures.localEquipment()
	end, { count })

	return e(InventoryPanel, { equipment = equipment })
end)
