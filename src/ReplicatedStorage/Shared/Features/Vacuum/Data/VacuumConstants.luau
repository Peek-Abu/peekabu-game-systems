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

-- Cleaning a grimy valuable (docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md §3.2): one Interaction
-- channel kind per cargo size, and the seconds one player takes to clean it fully (rates add across players).
local GRIME_KINDS: { [string]: string } = {
	tiny = "grime-tiny",
	light = "grime-light",
	medium = "grime-medium",
	heavy = "grime-heavy",
	bulky = "grime-bulky",
}
local GRIME_SECONDS: { [string]: number } = { tiny = 3, light = 3.5, medium = 5, heavy = 7, bulky = 9 }

-- Ordered, so a seeded roll picks the same kinds.
local PILE_KIND_LIST: { string } = { "paper", "debris", "cables" }

return table.freeze({
	TOOL_NAME = "Vacuum",
	TOOL_ATTRIBUTE = "CleanupCrewVacuum",
	PUBLIC_EQUIPPED_FIELD = "vacuumEquipped",
	TOOL_REFRESH_INTERVAL = 0.1,
	-- The Interaction channel kind a pile carries (its ChannelKind attribute).
	CHANNEL_KIND = "pile",
	-- CollectionService tag on every pile (the client's aim and the shrink follow it).
	PILE_TAG = "VacuumPile",
	PILE_KIND_ATTRIBUTE = "PileKind",
	-- CollectionService tag on a grimy valuable while it can be cleaned (Cargo tags it; the aim, the channel's
	-- re-check and the noise follow it), and its channel kinds and clean-up times by cargo size.
	GRIME_TAG = "VacuumGrime",
	GRIME_KINDS = table.freeze(GRIME_KINDS),
	GRIME_SECONDS = table.freeze(GRIME_SECONDS),
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
	-- Seconds a vacuuming player stays counted after their channel's last tick (the channel asks every 0.1 s).
	MAKER_WINDOW = 0.5,
	NOISE_RADIUS = 40,
	-- A pile shrinks to this fraction of its size as progress reaches full.
	MIN_SCALE = 0.35,
	-- The hold-to-vacuum Input action and how often the client re-aims.
	ACTION = "vacuum",
	AIM_INTERVAL = 0.1,
	-- Which pile is being cleaned (VacuumTargetRules, studs flat to a pile's rim): within 2 of the floor head,
	-- or 1 of the feet, or 5 of the feet inside a cone (dot 0.5, 60 degrees each side) round the body's facing;
	-- never one more than 6 up or down. The server re-checks every tick with TARGET_SLACK more studs, as it
	-- sees the vacuumer a moment later than the client that picked the pile.
	TARGET = table.freeze({ head = 2, underfoot = 1, range = 5, minDot = 0.5, height = 6 }),
	TARGET_SLACK = 2,
	-- Where a dust bag lands: this far ahead of the HumanoidRootPart, on the floor under that point, kept inside
	-- (CarryPlacementSystem.floorNear from the root, so never through a wall); and how far its centre stays from
	-- a wall (the bag is 2 studs wide).
	BAG_OFFSET = CFrame.new(0, 0, -2.5),
	BAG_WALL_MARGIN = 1.15,
	-- Feel (spec §7 "Vacuuming: suction particles into the nozzle, pile shrinks, rising whine, pop + sparkle,
	-- canister fills"; "Canister full: chime, dust bag pops out"). The whine rises with the pile's progress.
	WHINE_PITCH_MIN = 0.85,
	WHINE_PITCH_MAX = 1.6,
	WHINE_VOLUME_MIN = 0.6,
	WHINE_VOLUME_MAX = 1.25,
	-- A pile that disappears after being vacuumed past POP_PROGRESS within the last POP_WINDOW seconds was
	-- cleared (pop + sparkle); anything else (a reset) vanishes quietly.
	POP_PROGRESS = 0.5,
	POP_WINDOW = 0.6,
	-- How far from a pile its vacuumer's hand is looked for (a little past RANGE).
	VACUUMER_RANGE = 10,
	SUCTION_RATE = 40,
	SUCTION_LIFETIME = 0.4,
	SUCTION_SIZE = 0.35,
	SUCTION_COLOR = Color3.fromRGB(190, 180, 160),
	SPARKLE_COUNT = 24,
	SPARKLE_LIFETIME = 0.6,
	SPARKLE_SPEED = 10,
	SPARKLE_COLOR = Color3.fromRGB(255, 240, 170),
	-- The backpack (VacuumVisualSystem): the model on the character, the canister gauge's dust insert (resized
	-- by each client from its owner's public `canister` fill, its Weld moved so its bottom stays put), the lamp
	-- that lights when the canister is full, and the wand's floor head (where suction streams to).
	BACKPACK_NAME = "VacuumBackpack",
	GAUGE_FILL_NAME = "GaugeFill",
	GAUGE_WELD_NAME = "GaugeWeld",
	LAMP_NAME = "FullLamp",
	FLOOR_HEAD_NAME = "FloorHead",
	-- The gauge eases toward its fill at this rate (1/s); a full canister shows full, lamp lit, this many seconds
	-- before the dust bag pops out and it drains.
	GAUGE_RATE = 6,
	GAUGE_FULL_HOLD = 1.2,
	LAMP_ON_COLOR = Color3.fromRGB(255, 196, 64),
	LAMP_OFF_COLOR = Color3.fromRGB(120, 92, 40),
	PILE_KINDS = table.freeze(PILE_KINDS),
	PILE_KIND_LIST = table.freeze(PILE_KIND_LIST),
})
