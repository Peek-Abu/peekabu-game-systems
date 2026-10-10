--!strict
--[=[
	CargoConstants: Cargo tuning and names (Cleanup Crew spec §4). Every number is a tuning hypothesis.
	Static data (spec-exempt).

	@class CargoConstants
]=]

-- Carry weight per size. Carry walks at CarryFormulas.walkSpeedFor(16, weight, 0.05, 0.4): tiny and light
-- 14.8 (any carried item puts you under Harlow's chase speed of 15), medium 12.8, heavy 10.4, bulky 8 (half).
local WEIGHT: { [string]: number } = { tiny = 1.5, light = 1.5, medium = 4, heavy = 7, bulky = 10 }

-- Noise radius (studs) of a drop, by size. M2's Noise feature reads these through CargoHandlingRules.
local DROP_NOISE: { [string]: number } = { tiny = 6, light = 14, medium = 24, heavy = 36, bulky = 40 }

-- Sizes too heavy to sprint with. The base has no sprint yet: data for when it does.
local NO_SPRINT: { [string]: boolean } = { heavy = true, bulky = true }

-- A fragile item's value fraction after 0, 1, then 2 or more impacts.
local FRAGILE_TIERS: { number } = { 1, 0.5, 0.25 }

-- The public-player fields that name what is in each pocket (absent = empty).
local PUBLIC_POCKET_FIELDS: { string } = { "pocket1", "pocket2" }

-- The office plant's leaves in front of the camera while you carry it (spec §4: "leaves partly block your
-- view"): camera-space offsets (x right, y up, -z forward), a few greens, one thin leaf size.
local LEAF_OFFSETS: { CFrame } = {
	CFrame.new(-0.9, -0.55, -1.6) * CFrame.Angles(math.rad(70), 0, math.rad(30)),
	CFrame.new(0.95, -0.6, -1.7) * CFrame.Angles(math.rad(75), 0, math.rad(-35)),
	CFrame.new(-0.55, -0.75, -1.5) * CFrame.Angles(math.rad(60), 0, math.rad(10)),
	CFrame.new(0.5, -0.8, -1.55) * CFrame.Angles(math.rad(65), 0, math.rad(-15)),
	CFrame.new(0.05, -0.7, -1.8) * CFrame.Angles(math.rad(80), 0, 0),
}
local LEAF_COLORS: { Color3 } = {
	Color3.fromRGB(46, 120, 52),
	Color3.fromRGB(62, 145, 66),
	Color3.fromRGB(38, 100, 44),
}

return table.freeze({
	WEIGHT = table.freeze(WEIGHT),
	DROP_NOISE = table.freeze(DROP_NOISE),
	NO_SPRINT = table.freeze(NO_SPRINT),
	FRAGILE_TIERS = table.freeze(FRAGILE_TIERS),
	-- Pockets: two slots, tiny items only.
	POCKET_SLOTS = 2,
	POCKET_SIZE = "tiny",
	PUBLIC_POCKET_FIELDS = table.freeze(PUBLIC_POCKET_FIELDS),
	-- The Input action that pockets the hands item.
	POCKET_ACTION = "pocket",
	-- The Input action that swaps the hands item with a pocket, or unpockets into empty hands (M2).
	SWAP_ACTION = "swap",
	-- A bulky item is held far out in front (the cabinet cart).
	BULKY_HOLD_OFFSET = CFrame.new(0, -1, -4.5),
	-- Attributes on a spawned item, and its label's name.
	ID_ATTRIBUTE = "CargoId",
	VALUE_ATTRIBUTE = "CargoValue",
	IMPACTS_ATTRIBUTE = "CargoImpacts",
	HIDDEN_ATTRIBUTE = "CargoHidden",
	LABEL_NAME = "CargoLabel",
	-- Interaction kinds Cargo registers (the truck bed and the desks / lockers carry them).
	LOAD_KIND = "cargo-load",
	SEARCH_KIND = "cargo-search",
	LOAD_DISTANCE = 16,
	SEARCH_DISTANCE = 8,
	SEARCH_HOLD = 0.8,
	-- The truck bed counts this far past its footprint, and this high above its top.
	BED_TOLERANCE = 1.5,
	BED_HEIGHT = 8,
	-- Noise: a jug's splash, a search, a rattle pulse (every RATTLE_INTERVAL while carried).
	SPLASH_NOISE = 70,
	SEARCH_NOISE = 12,
	RATTLE_NOISE = 12,
	RATTLE_INTERVAL = 2,
	-- Pocketed items scatter this far around where their owner died or left.
	SCATTER_RADIUS = 4,
	-- How often (seconds) each player's position is remembered, for scattering when their character is gone.
	ROOT_SAMPLE_INTERVAL = 0.5,
	-- The pile a spilled recycling box becomes.
	SPILL_PILE_KIND = "paper",
	-- Graybox item labels are seen within this many studs.
	LABEL_DISTANCE = 24,
	-- How far down the floor is looked for under a spill or a scattered item.
	FLOOR_PROBE = 20,
	-- Feel (spec §7 "Banking: item swoops into the truck, cha-ching, '+15' floater"). Positional Cargo sounds the
	-- server plays reach this far.
	SOUND_RADIUS = 120,
	-- The swoop: seconds along the arc, its lift, the gap between several items, and how small it ends.
	SWOOP_SECONDS = 0.55,
	SWOOP_HEIGHT = 6,
	SWOOP_STAGGER = 0.12,
	SWOOP_END_SCALE = 0.35,
	-- The "+N" floaters: life, rise, spacing between two, draw distance, look.
	FLOATER_SECONDS = 1.4,
	FLOATER_RISE = 4,
	FLOATER_SPACING = 1.3,
	FLOATER_DISTANCE = 150,
	FLOATER_FONT = Enum.Font.Oswald,
	CLEARANCE_COLOR = Color3.fromRGB(110, 210, 120),
	BONUS_COLOR = Color3.fromRGB(100, 175, 255),
	LEAF_SIZE = Vector3.new(1.4, 0.05, 0.7),
	LEAF_COLORS = table.freeze(LEAF_COLORS),
	LEAF_OFFSETS = table.freeze(LEAF_OFFSETS),
	-- M2 traits: the water jug's slippery puddle (lasts PUDDLE_SECONDS), and slipping on it: crossing at
	-- SLIP_SPEED or faster, root within SLIP_HEIGHT of it, at most once per SLIP_COOLDOWN; a slip stands the
	-- player down for SLIP_SECONDS and shoves them on (impulse SLIP_PUSH x mass). Checked every SLIP_CHECK.
	PUDDLE_TAG = "CargoPuddle",
	PUDDLE_SIZE = Vector3.new(7, 0.15, 7),
	PUDDLE_COLOR = Color3.fromRGB(120, 180, 230),
	PUDDLE_SECONDS = 25,
	SLIP_SPEED = 8,
	SLIP_HEIGHT = 5,
	SLIP_COOLDOWN = 2,
	SLIP_SECONDS = 0.9,
	SLIP_PUSH = 25,
	SLIP_CHECK = 0.1,
})
