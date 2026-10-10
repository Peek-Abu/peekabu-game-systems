--!strict
--[=[
	VacuumConstants: vacuum tuning and names (Cleanup Crew spec §4 "Vacuum"). Every number is a tuning
	hypothesis. Static data (spec-exempt).

	@class VacuumConstants
]=]

export type PileStyle = {
	size: Vector3,
	color: Color3,
	material: Enum.Material,
}

-- The three pile visuals (graybox).
local PILE_KINDS: { [string]: PileStyle } = {
	paper = { size = Vector3.new(4, 1.2, 4), color = Color3.fromRGB(235, 230, 215), material = Enum.Material.Fabric },
	debris = { size = Vector3.new(3.5, 1, 3.5), color = Color3.fromRGB(120, 105, 90), material = Enum.Material.Slate },
	cables = { size = Vector3.new(3, 0.8, 3), color = Color3.fromRGB(25, 25, 25), material = Enum.Material.Plastic },
}

-- Ordered, so a seeded roll picks the same kinds.
local PILE_KIND_LIST: { string } = { "paper", "debris", "cables" }

return table.freeze({
	-- The Interaction channel kind a pile carries (its ChannelKind attribute).
	CHANNEL_KIND = "pile",
	-- CollectionService tag on every pile (the client's aim and the shrink follow it).
	PILE_TAG = "VacuumPile",
	PILE_KIND_ATTRIBUTE = "PileKind",
	BASE_SIZE_ATTRIBUTE = "PileBaseSize",
	-- Aim at a pile within this many studs; one player clears it in DURATION seconds.
	RANGE = 8,
	DURATION = 2.5,
	-- Piles per canister; the next one pops a dust bag (this Cargo kind) and empties it.
	CANISTER_CAPACITY = 3,
	DUST_BAG_KIND = "dustBag",
	-- The public-player field holding a player's canister fill.
	PUBLIC_FIELD = "canister",
	-- Noise seam (M2): a pulse every NOISE_INTERVAL seconds while a pile is being vacuumed.
	NOISE_INTERVAL = 1,
	NOISE_RADIUS = 40,
	-- A pile shrinks to this fraction of its size as progress reaches full.
	MIN_SCALE = 0.35,
	-- The hold-to-vacuum Input action, how often the client re-aims, and how squarely it must face a pile.
	ACTION = "vacuum",
	AIM_INTERVAL = 0.1,
	AIM_MIN_DOT = 0.35,
	-- Where a dust bag lands, relative to the HumanoidRootPart (at the feet, a little ahead).
	BAG_OFFSET = CFrame.new(0, -3, -2.5),
	PILE_KINDS = table.freeze(PILE_KINDS),
	PILE_KIND_LIST = table.freeze(PILE_KIND_LIST),
})
