--!strict
--[=[
	UIAssets: the registry of image asset ids the UI references, by name.

	The single home for `rbxassetid://` literals in UI code — the CI asset-id gate bans them anywhere
	else, for the same "six id sources" reason it bans scattered animation ids. A screen names an
	asset (`UIAssets.bar.fill`), never pastes a number, so a re-skin or a re-upload is one edit here.

	Ids transcribed from the authored HUD in VentureTestingPlace (read-only), which is the reference
	for the game's look while its art is ported.

	@class UIAssets
]=]

local UIAssets = {}

-- The layered resource bar (health / rot / stamina): a fill sprite tinted per resource, a frame
-- drawn over it, and tick marks that segment it. All three bars are this same set, different tint.
UIAssets.bar = table.freeze({
	fill = "rbxassetid://120234739704670", -- the coloured fill (tinted per resource)
	frame = "rbxassetid://128599962592774", -- the border/frame drawn over the fill
	innerShade = "rbxassetid://13186615482", -- subtle inner shading under the fill
	tick = "rbxassetid://70713933546571", -- a segment divider
})

-- The XP bar (top-centre): a tinted textured fill over the authored dark track, plus the level badge.
-- NOTE: the visible fill is `16585337652` (the beveled texture); `16385950468` is only an invisible
-- sizing container in Venture, so it is not registered here.
UIAssets.xp = table.freeze({
	fill = "rbxassetid://16585337652", -- the visible textured XP fill (tinted per state)
	track = "rbxassetid://129313874124713", -- the authored backdrop track (a dark backing — draw it
	-- translucent so it reads as a recessed slot, not a solid black slab)
	tick = "rbxassetid://16385466981", -- the notch / divider sprite
	badge = "rbxassetid://16551567318", -- the level badge plate
	badgeGlow = "rbxassetid://16551561124", -- the badge's glow layer
})

-- The item slot (inventory grid + equipment): the slot frame that holds the item icon, with the rarity
-- border drawn OVER it (tinted per rarity), plus the favourite star.
-- NOTE: the authored template also carries a shine sprite (`13839848680`), but it ships `Visible = false`
-- and no script ever references it — authoring residue, so it is not registered here.
UIAssets.slot = table.freeze({
	rarity = "rbxassetid://82380525983864", -- the rarity border (tinted by RarityDisplay.borderColor)
	frame = "rbxassetid://119127175093282", -- the slot frame the icon sits in
	favorite = "rbxassetid://3926305904", -- the favourite star (deferred until actions land)
})

-- Chrome for full-screen panels (the inventory, and the panels that follow it).
UIAssets.panel = table.freeze({
	vignette = "rbxassetid://9400204309", -- the oversized edge vignette behind the panel
	-- The inventory's backdrop plate. Drawn for a PORTRAIT panel (~0.76 wide-to-tall) — keep an aspect
	-- constraint on whatever renders it, or the plate's border and grid recess distort.
	inventoryBackdrop = "rbxassetid://117360857259364",
})

-- The category tab row: the sprite that marks the active tab (the authored tabs carry no fill).
UIAssets.tab = table.freeze({
	highlight = "rbxassetid://15502743420",
})

-- The inventory's sort control: a small square button that opens the sort-mode list.
UIAssets.sort = table.freeze({
	button = "rbxassetid://16468615207",
})

-- The equipment paperdoll down the left of the inventory: two stacked plates, armour above weapons.
UIAssets.equipment = table.freeze({
	armourBackdrop = "rbxassetid://81263013907893", -- the tall plate behind the armour slots
	weaponBackdrop = "rbxassetid://78947230266484", -- the shorter plate behind the weapon slots
	appearancesArrow = "rbxassetid://15636540873", -- the arrow capping each end of the APPEARANCES tab
})

-- The selected item's detail card. Layered back to front: the plate, the rarity bar tinted per rarity,
-- the stat bar behind the primary stat, then the outlines and separation lines over everything.
-- Drawn for a ~0.69 wide-to-tall card; keep an aspect constraint on whatever renders it.
--[=[
	The bank's currency strip, off the authored `Banker.BankerMenu.TransferCoinMenu`. `buttonPlate` is
	one asset doing two jobs there — every transfer button AND the strip's title bar — which is why it is
	named for its shape rather than for either use.
]=]
UIAssets.bank = table.freeze({
	menuPlate = "rbxassetid://16468595527", -- the strip's backing (authored tint: a flat grey)
	buttonPlate = "rbxassetid://16757394232", -- one transfer button, and the title bar
	coinWell = "rbxassetid://16468615207", -- the amount field's recess (the sort button's asset too)
	coinIcon = "rbxassetid://16808958468", -- the coin, beside a balance and in the amount field
	closeButton = "rbxassetid://9399644416", -- the round plate behind the screen's X
})

UIAssets.itemCard = table.freeze({
	plate = "rbxassetid://112950982769582", -- the card's background plate
	rarityBar = "rbxassetid://131976192542431", -- the rarity wash (tinted by RarityDisplay.accentColor)
	statBar = "rbxassetid://101267710131657", -- the tinted strip behind the primary stat / level line
	outlines = "rbxassetid://95502032312292", -- the card's border, drawn over the content
	separators = "rbxassetid://78008172951696", -- the rules dividing the card's sections
	actionPlate = "rbxassetid://108532933311558", -- one row of the action menu beside the card
})

return table.freeze(UIAssets)
