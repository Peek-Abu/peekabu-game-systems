--!strict
--[=[
	VacuumSkinRegistry: the backpack vacuum's skins, and which players wear one other than Standard Issue.

	A skin is a template under ReplicatedStorage.Assets.CleanupCrew (built by characters/vacuum/
	build_backpack_vacuum.py, a skin with `--skin characters/vacuum/skins/<name>/skin.json`) plus its hose texture.
	Every skin shares the standard pack's mount, outlet, holster, straps and wand piece sizes (the grip contract,
	characters/vacuum/README.md), so VacuumVisualSystem treats them all alike.

	The owner allowlist is MVP ONLY (like EmployeeSkinRegistry): a hard-coded list so the owner can try a skin while
	playtesting; it is not an unlock, purchase or inventory system. Replace it with a real owned-skins slice
	(PlayerDataSliceSystem) when skins are earned or sold (the skin shop is after the MVP).

	@class VacuumSkinRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumAssets = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumAssets)

export type SkinDef = {
	name: string,
	displayName: string,
	rarity: string,
	-- The template's name under ReplicatedStorage.Assets.CleanupCrew.
	template: string,
	-- The hose Beam's texture.
	hoseTexture: string,
}

local DEFAULT = "StandardIssue"

local SKINS: { [string]: SkinDef } = {
	StandardIssue = table.freeze({
		name = "StandardIssue",
		displayName = "Standard Issue",
		rarity = "Common",
		template = "Vacuum",
		hoseTexture = VacuumAssets.HOSE_TEXTURE,
	}),
	-- Victorian steampunk: a riveted brass canister under a glass dome, pressure gauges, leather straps, a copper
	-- hose, a wooden handle and a brass bellows floor head (characters/vacuum/skins/brass-bellows).
	BrassBellows = table.freeze({
		name = "BrassBellows",
		displayName = "Brass Bellows",
		rarity = "Rare",
		template = "VacuumBrassBellows",
		hoseTexture = VacuumAssets.HOSE_TEXTURE_COPPER,
	}),
}

-- UserId -> skin name. MVP only (see above).
local OWNER_SKINS: { [number]: string } = {
	[20661908] = "BrassBellows", -- icemonkey1 (the owner)
}

local VacuumSkinRegistry = {
	DEFAULT = DEFAULT,
	SKINS = table.freeze(SKINS),
}

-- The skin called `name`, nil when there is none.
function VacuumSkinRegistry.get(name: string): SkinDef?
	return SKINS[name]
end

-- The skin this player's vacuum wears, nil for Standard Issue.
function VacuumSkinRegistry.skinFor(userId: number): string?
	return OWNER_SKINS[userId]
end

return table.freeze(VacuumSkinRegistry)
