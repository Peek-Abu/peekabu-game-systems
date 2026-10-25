--!strict
--[=[
	VacuumSkinRegistry: the backpack vacuum's skins (their art). Who wears which is the Cosmetic loadout's `vacuum`
	(each skin is a Cosmetic item `Vacuum.<name>`, owned and bought like any skin).

	A skin is a template under ReplicatedStorage.Assets.CleanupCrew (built by characters/vacuum/
	build_backpack_vacuum.py, a skin with `--skin characters/vacuum/skins/<name>/skin.json`) plus its hose texture.
	Every skin shares the standard pack's mount, outlet, holster, straps and wand piece sizes (the grip contract,
	characters/vacuum/README.md), so VacuumVisualSystem treats them all alike.

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

local VacuumSkinRegistry = {
	DEFAULT = DEFAULT,
	SKINS = table.freeze(SKINS),
}

-- The skin called `name`, nil when there is none.
function VacuumSkinRegistry.get(name: string): SkinDef?
	return SKINS[name]
end

return table.freeze(VacuumSkinRegistry)
