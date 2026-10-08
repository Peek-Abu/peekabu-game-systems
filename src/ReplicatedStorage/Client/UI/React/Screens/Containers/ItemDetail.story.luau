--!strict
--[=[
	ItemDetail.story: the detail card in every state it can currently reach.

	The card has a lot of conditional surface — the reserved primary line, an amount line for stacks, the
	level row's met/unmet colouring, comparison deltas, the action menu — and most of those states are
	awkward to produce in a running game (you need the right item, the right level, and the right thing
	equipped). Each is a control here instead.

	The Rotbound control previews the item-status treatment, which is NOT wired to any data — see the
	handover note in ItemDetail for what making it real involves.

	The Rarity control also steps the pastel ACCENT palette, which should read as a different set of
	colours from the saturated border tints in Slot.story, since Venture uses two.

	@class ItemDetail.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local ItemDetail = require(ReplicatedStorage.Client.UI.React.Screens.Containers.ItemDetail)
local StoryFixtures = require(ReplicatedStorage.Client.UI.React.StoryFixtures)

local e = React.createElement

-- Wide enough to show the action menu, which hangs off the card's right edge.
local CARD_WIDTH = 0.34

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Rarity = UILabs.Choose(StoryFixtures.rarities()),
		-- Pinned cards carry the action menu; hovered ones are a peek without it.
		Pinned = true,
		-- A stack fills the reserved primary line with "AMOUNT: n/max"; gear leaves it blank.
		Stackable = false,
		-- Drive the stack toward its ceiling to see the line turn alarm red.
		Quantity = 5,
		-- Below the item's requirement, the level row turns red.
		PlayerLevel = 30,
		-- Compare against a weaker item, so the stat rows show gains, losses, and a stat only the
		-- equipped item has.
		CompareAgainstEquipped = true,
		-- PREVIEW: rotbound is a prop, not data. It swaps the status line, adds the purple overlay, and
		-- obscures the item's numbers and prose.
		Rotbound = false,
	},
}, function(props)
	local controls = props.controls
	local item = StoryFixtures.displayItem(controls.Rarity, 1)

	if controls.Stackable then
		item.stackMax = 20
		item.quantity = controls.Quantity
		item.stats = {}
		item.requiredLevel = nil
	end

	local equippedItem = if controls.CompareAgainstEquipped then StoryFixtures.comparisonItem() else nil

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
		BorderSizePixel = 0,
	}, {
		card = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.4, 0.5),
			Size = UDim2.fromScale(CARD_WIDTH, 1),
			BackgroundTransparency = 1,
		}, {
			inner = e(ItemDetail, {
				item = item,
				equippedItem = equippedItem,
				pinned = controls.Pinned,
				playerLevel = controls.PlayerLevel,
				status = if controls.Rotbound then "rotbound" else nil,
			}),
		}),
	})
end)
