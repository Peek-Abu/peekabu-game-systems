--!strict
--[=[
	InventoryCharacterPanel: one employee's page in the Inventory, under the menu bar (back, the employee's head and
	name, the tabs Skins · Idles · About: InventoryScreen draws it). Concepts: characters/ui/character-ui/frames3/
	char-skins.jpg and char-about.jpg. Three columns:
	- left: a grid of item cards (rarity-coloured card, an inset stage with the item in 3D, a rarity ribbon, the name,
	  the footer band saying where it comes from, New! and "On" ribbons), or on About: who they are and a fun fact;
	- middle: the hero: the selected skin LIVE (idle playing) on a raised platform in the rarity's colour;
	- right: the selected item's detail (ribbons, the big name, the lore box (a quote when the employee speaks), Styles, Comes with tiles, the
	  main button: Wear / Wearing / See in Shop with its price / where else to get it), or on About: the ability card,
	  the stat bars and "Every employee can finish every job, even alone."
	All of it is InventoryViewModel output; nothing is per character. Looking at a New! item marks it seen.
	The columns are split out of this file: InventoryItemGrid (left), InventoryItemDetail (right), InventoryAboutColumns
	(About), with the props type and layout pieces in InventoryPanelBlocks; this file keeps the hero and the wiring.
	Presentational (exempt; story in InventoryScreen.story).

	@class InventoryCharacterPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local CosmeticOutfitRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticOutfitRules)
local InventoryAboutColumns = require(script.Parent.InventoryAboutColumns)
local InventoryItemDetail = require(script.Parent.InventoryItemDetail)
local InventoryItemGrid = require(script.Parent.InventoryItemGrid)
local InventoryPanelBlocks = require(script.Parent.InventoryPanelBlocks)
local VM = require(script.Parent.InventoryViewModel)

local e = React.createElement

-- A vacuum skin's hero shows your employee from behind (a little round, so the face still shows): the pack is on the back.
local BACK_TURN = 150

export type InventoryCharacterPanelProps = InventoryPanelBlocks.InventoryCharacterPanelProps

local group = InventoryPanelBlocks.group

-- The hero: the item live on a 3D platform in the rarity's colour. For a vacuum skin: you (your employee as you
-- are now, rank lanyard and all) wearing the selected vacuum, from behind.
local function hero(
	props: InventoryCharacterPanelProps,
	skinKey: string,
	rarity: CosmeticTypes.Rarity,
	tryOn: string?,
	style: number,
	emote: string?,
	idle: string?
): React.ReactNode
	local shade = UIToonConstants.rarity(rarity)
	local outfit = if tryOn ~= nil
		then CosmeticOutfitRules.tryOn(CosmeticOutfitRules.current(props.loadout, props.owns), tryOn)
		else nil
	return group({
		model = e(ToonViewport, {
			employee = if outfit == nil then props.employee else nil,
			outfit = outfit,
			-- Your own employee: it wears your rank lanyard (owner 11-15: only surfaces that show you do).
			lanyard = true,
			turn = if outfit ~= nil then BACK_TURN else nil,
			skin = skinKey,
			style = style,
			idle = if outfit == nil then idle else nil,
			live = true,
			react = props.openedAt,
			-- The player turns it round (drag, flick, right stick).
			spin = true,
			-- On the Emotes tab the hero loops the selected emote, in the skin you wear.
			emote = emote,
			framing = "full",
			platform = { top = shade.base, side = shade.lo },
			size = UDim2.fromScale(1, 0.94),
			zIndex = 3,
		}),
	})
end

local function InventoryCharacterPanel(props: InventoryCharacterPanelProps): React.ReactNode
	local layout = props.layout
	-- The colour style picked on a chip, for the item it was picked on (another item shows its worn style again).
	local picked, setPicked = React.useState({ id = "", style = 1 })
	local look = props.loadout.looks[props.employee]
	local wornSkin = if look ~= nil then look.skin else CosmeticRegistry.defaultOf(props.employee, "skin").id

	local left: React.ReactNode
	local right: React.ReactNode
	local heroSkin = VM.skinKey(wornSkin)
	local heroRarity: CosmeticTypes.Rarity = "default"
	local tryOn: string? = nil
	local heroStyle = 1
	local heroEmote: string? = nil
	local heroIdle: string? = VM.heroIdle(props.employee, props.loadout, props.owns, nil)
	local seenId = ""
	if props.tab == "about" then
		left, right = InventoryAboutColumns(props)
	else
		local sections = VM.sections(props.tab, props.employee, props.loadout, props.owns)
		-- The kinds on this tab (Skins holds the vacuum skins too); the first row's kind opens selected.
		local kinds: { [string]: boolean } = {}
		for _, section in sections do
			for _, entry in section.cards do
				local item = CosmeticRegistry.get(entry.id)
				if item ~= nil then
					kinds[item.kind] = true
				end
			end
		end
		local first = sections[1]
		local cards: { VM.ItemCard } = if first ~= nil then first.cards else {}
		local selectedId = props.selected
		local selectedItem = if selectedId ~= nil then CosmeticRegistry.get(selectedId) else nil
		if selectedItem == nil or kinds[selectedItem.kind] ~= true then
			selectedItem = nil
			for _, entry in cards do
				if entry.worn then
					selectedItem = CosmeticRegistry.get(entry.id)
				end
			end
			if selectedItem == nil and cards[1] ~= nil then
				selectedItem = CosmeticRegistry.get(cards[1].id)
			end
		end
		if selectedItem ~= nil then
			local item = selectedItem
			local view = VM.detail(
				item,
				props.loadout,
				props.owns,
				props.employee,
				if picked.id == item.id then picked.style else nil
			)
			heroStyle = view.styles.selected
			left = InventoryItemGrid(props, sections, item.id)
			-- A chip only previews the style; Wear (enabled for another style of a worn skin) puts it on.
			right = InventoryItemDetail(props, view, item, heroStyle, function(index: number)
				setPicked({ id = item.id, style = index })
			end)
			heroRarity = selectedItem.rarity
			heroEmote = if selectedItem.kind == "emote" then selectedItem.id else nil
			heroIdle = VM.heroIdle(props.employee, props.loadout, props.owns, selectedItem)
			if selectedItem.kind == "skin" then
				heroSkin = VM.skinKey(selectedItem.id)
			elseif selectedItem.kind == "vacuum" then
				tryOn = selectedItem.id
			end
			if view.new then
				seenId = selectedItem.id
			end
		end
	end

	-- Looking at a New! item clears its flag (the server records it; the flag goes when the loadout syncs).
	local onSeen = props.onSeen
	React.useEffect(function()
		if seenId ~= "" then
			onSeen({ seenId })
		end
	end, { seenId })

	return group({
		left = e("Frame", {
			Size = UDim2.new(0, layout.gridWidth, 1, 0),
			BackgroundTransparency = 1,
		}, { content = left }),
		hero = e("Frame", {
			Position = UDim2.fromOffset(layout.gridWidth + layout.gap, 0),
			Size = UDim2.new(0, layout.heroWidth, 1, 0),
			BackgroundTransparency = 1,
		}, { content = hero(props, heroSkin, heroRarity, tryOn, heroStyle, heroEmote, heroIdle) }),
		right = e("Frame", {
			Position = UDim2.fromOffset(layout.gridWidth + layout.heroWidth + 2 * layout.gap, 0),
			Size = UDim2.new(0, layout.detailWidth, 1, 0),
			BackgroundTransparency = 1,
		}, { content = right }),
	})
end

return InventoryCharacterPanel
