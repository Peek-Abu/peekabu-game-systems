--!strict
--[=[
	CargoConstants: Cargo tuning and names (Cleanup Crew spec §4). Every number is a tuning hypothesis.
	Static data (spec-exempt).

	@class CargoConstants
]=]

-- Carry weight per size: what Carry registers for each kind (its hold pose is planned against it). The walk while
-- loaded is CarryFormulas.carrierSpeed(16, load) = 16 x max(0.4, 1 - 0.05 x load), the sprint 23 x the same factor.
-- A big item (medium / heavy / bulky) in the hands loads its WEIGHT: medium 12.8 walk, heavy 10.4, bulky 8.
local WEIGHT: { [string]: number } = { tiny = 1.5, light = 1.5, medium = 4, heavy = 7, bulky = 10 }

-- The hotbar inventory (docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md). Small sizes go
-- straight into a free item slot on pick-up (E) and can be drawn into one hand; anything else is a big item, held in
-- both hands, which locks the hotbar until it is dropped.
local SMALL_SIZES: { [string]: boolean } = { tiny = true, light = true }

-- The public-player fields that publish each item slot (1-4, the hotbar's 2-5): its kind, its value when it is known
-- (trash always; a valuable once appraised; absent = "$???"), and an appraised jackpot's name.
export type SlotFields = { kind: string, value: string, variant: string }
local SLOT_FIELDS: { SlotFields } = {}
for index = 1, 4 do
	table.insert(
		SLOT_FIELDS,
		table.freeze({ kind = `inv{index}`, value = `inv{index}Value`, variant = `inv{index}Variant` })
	)
end

-- The Input actions that select hotbar slots 1-5 (1 = the vacuum), keyboard 1-5 and gamepad none (scroll / LB-RB).
local SLOT_ACTIONS: { string } = { "hotbar1", "hotbar2", "hotbar3", "hotbar4", "hotbar5" }

-- Noise radius (studs) of a drop, by size. M2's Noise feature reads these through CargoHandlingRules.
local DROP_NOISE: { [string]: number } = { tiny = 6, light = 14, medium = 24, heavy = 36, bulky = 40 }

-- A fragile item's value fraction after 0, 1, then 2 or more impacts.
local FRAGILE_TIERS: { number } = { 1, 0.5, 0.25 }

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

-- The Gloom a valuable's grime holds at full grime, by cargo size (GLOOM_BY_SIZE below).
local GLOOM_BY_SIZE: { [string]: number } = { tiny = 5, light = 8, medium = 15, heavy = 25, bulky = 35 }

return table.freeze({
	WEIGHT = table.freeze(WEIGHT),
	DROP_NOISE = table.freeze(DROP_NOISE),
	FRAGILE_TIERS = table.freeze(FRAGILE_TIERS),
	-- The hotbar: HOTBAR_SLOTS slots, VACUUM_SLOT the vacuum, the rest ITEM_SLOTS item slots (hotbar slot = item
	-- slot + 1). A small item carried (pocketed or in one hand) loads SMALL_LOAD: 1 item walks 15.6 / sprints 22.4,
	-- 2 15.2 / 21.9, 3 14.8 / 21.3, 4 14.4 / 20.7 (still a hair past the Manager's chase of 20). A big item adds its
	-- WEIGHT on top: a monitor with 3 small items walks 11.6 / sprints 16.7.
	HOTBAR_SLOTS = 5,
	VACUUM_SLOT = 1,
	ITEM_SLOTS = 4,
	SMALL_SIZES = table.freeze(SMALL_SIZES),
	SMALL_LOAD = 0.5,
	SLOT_FIELDS = table.freeze(SLOT_FIELDS),
	-- The public fields naming the item slot whose item is in the hands (absent = none) and the hotbar slot chosen
	-- with empty hands (absent = none; the vacuum's own public `vacuumEquipped` says when slot 1 is out).
	PUBLIC_HANDS_FIELD = "invHands",
	PUBLIC_SELECTED_FIELD = "invSelected",
	SLOT_ACTIONS = table.freeze(SLOT_ACTIONS),
	-- The gamepad's previous / next slot actions (d-pad left / right; the mouse wheel stays the camera zoom).
	PREVIOUS_SLOT_ACTION = "hotbarPrevious",
	NEXT_SLOT_ACTION = "hotbarNext",
	-- A bulky item is held far out in front (the cabinet cart).
	BULKY_HOLD_OFFSET = CFrame.new(0, -1, -4.5),
	-- Attributes on a spawned item, and its label's name.
	ID_ATTRIBUTE = "CargoId",
	VALUE_ATTRIBUTE = "CargoValue",
	IMPACTS_ATTRIBUTE = "CargoImpacts",
	HIDDEN_ATTRIBUTE = "CargoHidden",
	-- Where an item came from, for analytics: "open", "pile" (uncovered by vacuuming), "desk" (searched), "scatter".
	SOURCE_ATTRIBUTE = "CargoSource",
	LABEL_NAME = "CargoLabel",
	-- Interaction kinds Cargo registers (the truck bed and the desks / lockers carry them).
	LOAD_KIND = "cargo-load",
	SEARCH_KIND = "cargo-search",
	LOAD_DISTANCE = 16,
	SEARCH_DISTANCE = 8,
	SEARCH_HOLD = 0.8,
	-- The truck bed counts this far past its footprint, and this high above its top.
	BED_TOLERANCE = 1.5,
	LOAD_REACH = 4,
	LANDING_TOLERANCE = 0.5,
	REST_SPEED = 1,
	REST_SECONDS = 0.3,
	THROW_MIN_FLIGHT = 0.35,
	THROW_MAX_FLIGHT = 8,
	BED_HEIGHT = 8,
	-- Noise: a jug's splash, a search, a rattle pulse (every RATTLE_INTERVAL while carried).
	SPLASH_NOISE = 70,
	SEARCH_NOISE = 12,
	RATTLE_NOISE = 12,
	RATTLE_INTERVAL = 2,
	-- A caught, dead or leaving player's pocketed items scatter this far around where they were.
	SCATTER_RADIUS = 4,
	-- How often (seconds) each player's position is remembered, for scattering when their character is gone.
	ROOT_SAMPLE_INTERVAL = 0.5,
	-- The pile a spilled recycling box becomes.
	SPILL_PILE_KIND = "paper",
	-- An item's price tag (M3b world UI, W5): its shell's tag and attributes (the client draws it,
	-- CargoBillboardSystem), its design size in px, and when it is drawn: seen within LABEL_DISTANCE studs (the
	-- shell's MaxDistance), mounted on a client within LABEL_DISTANCE of the camera and kept until LABEL_KEEP_DISTANCE
	-- (no flicker at the edge), checked every LABEL_CHECK seconds.
	LABEL_TAG = "CargoPriceTag",
	LABEL_KEYS = table.freeze({
		name = "CargoTagName",
		category = "CargoTagCategory",
		value = "CargoTagValue",
		fragile = "CargoTagFragile",
		impacts = "CargoTagImpacts",
		hidden = "CargoTagHidden",
		-- A valuable's grime (0-1), whether it is appraised, its jackpot name, and when it was appraised (server
		-- time, so a fresh appraisal's stamp pops). Absent on trash.
		grimy = "CargoTagGrimy",
		clean = "CargoTagClean",
		appraised = "CargoTagAppraised",
		variant = "CargoTagVariant",
		appraisedAt = "CargoTagAppraisedAt",
		-- Its grime is locked (picked up dirty: sealed as found), so the tag reads "GRIME LOCKED".
		sealed = "CargoTagSealed",
	}),
	LABEL_PX = Vector2.new(260, 70),
	LABEL_DISTANCE = 24,
	LABEL_KEEP_DISTANCE = 28,
	LABEL_CHECK = 0.2,
	-- The loot loop (docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md §3). A valuable pays
	-- base x fragile tier x grime factor, the grime factor GRIME_FLOOR + (1 - GRIME_FLOOR) x cleanliness: 30% of its
	-- value at full grime, all of it clean. It is appraised (its "$???" revealed) once cleanliness first reaches
	-- APPRAISE_AT, and stays appraised.
	GRIME_FLOOR = 0.3,
	APPRAISE_AT = 0.65,
	-- Depth: x(1 + DEPTH_VALUE_STEP x (rooms from the bay - 1)), never below 1 or above DEPTH_VALUE_MAX (the next room
	-- pays x1, the far rooms x1.45-1.6).
	DEPTH_VALUE_STEP = 0.15,
	DEPTH_VALUE_MAX = 1.6,
	-- The Gloom a valuable's grime holds at full grime, by size (docs/superpowers/specs/
	-- 2026-10-16-cleanup-crew-gloom-gleam-economy-design.md §3.2): cleaning it removes that much toward the contract,
	-- in step with its cleanliness. What is left when it is picked up dirty (its grime locks) is never removed.
	GLOOM_BY_SIZE = table.freeze(GLOOM_BY_SIZE),
	-- A valuable's server-owned state: its base (true) value, cleanliness, appraisal, jackpot name, and when it was
	-- appraised (server time).
	BASE_VALUE_ATTRIBUTE = "CargoBaseValue",
	CLEAN_ATTRIBUTE = "CargoClean",
	APPRAISED_ATTRIBUTE = "CargoAppraised",
	VARIANT_ATTRIBUTE = "CargoVariant",
	APPRAISED_AT_ATTRIBUTE = "CargoAppraisedAt",
	-- "Clean it where you find it": a valuable's grime locks the first time it is picked up while not spotless. It
	-- keeps its cleanliness and value, is never a vacuum target again, and the truck appraises it as it is. The first
	-- lock of a shift tells its carrier why, on a small sticky note (Shift's "sticky" toast style).
	SEALED_ATTRIBUTE = "CargoSealed",
	GRIME_LOCK_TOAST_STYLE = "sticky",
	GRIME_LOCK_TOAST_SECONDS = 4,
	GRIME_LOCK_HINT = "Grime locked: clean it before you lift it.",
	-- Set on a dust pile that hides an item (Office): its glint.
	BURIED_ATTRIBUTE = "CargoBuried",
	-- An appraisal is told (a small sticky slip off-centre, Shift's "slip" toast style, "slipJackpot" for a jackpot;
	-- never the big centre stamp, which is kept for shift milestones) to every crew member this close, briefly; its
	-- tag's own APPRAISED stamp pops when it is younger than STAMP_FRESH_SECONDS.
	APPRAISAL_TELL_DISTANCE = 30,
	APPRAISAL_TOAST_STYLE = "slip",
	APPRAISAL_JACKPOT_STYLE = "slipJackpot",
	APPRAISAL_TOAST_SECONDS = 2.5,
	STAMP_FRESH_SECONDS = 2,
	-- The grime look (client): a Highlight in GRIME_COLOR, fill transparency GRIME_FILL_TRANSPARENCY at full grime
	-- easing to 1 when clean, and dust motes at up to GRIME_MOTE_RATE per second, drawn within GRIME_VISUAL_DISTANCE
	-- of the camera (Highlights are capped per client).
	GRIME_COLOR = Color3.fromRGB(64, 48, 30),
	GRIME_FILL_TRANSPARENCY = 0.35,
	GRIME_MOTE_RATE = 4,
	GRIME_MOTE_COLOR = Color3.fromRGB(150, 132, 104),
	GRIME_VISUAL_DISTANCE = 70,
	GRIME_VISUAL_CHECK = 0.25,
	-- The buried pile's glint: a few sparkles every GLINT_INTERVAL_MIN..MAX seconds, seen within GLINT_DISTANCE.
	GLINT_DISTANCE = 20,
	GLINT_INTERVAL_MIN = 3,
	GLINT_INTERVAL_MAX = 5.5,
	GLINT_COUNT = 3,
	GLINT_SIZE = 0.35,
	GLINT_LIFETIME = 0.45,
	GLINT_COLOR = Color3.fromRGB(255, 244, 196),
	-- A buried item's reveal (gold burst) and an appraisal (paper flecks).
	REVEAL_COUNT = 32,
	REVEAL_COLOR = Color3.fromRGB(255, 205, 70),
	-- The reveal sound's value layer grows with the revealed item's base value (CargoBaseValue): the lowest base each
	-- tier starts at (below `mid` is "low"). Buried kinds roll 30-170 before depth, so "jackpot" is mostly a jackpot roll.
	REVEAL_TIERS = table.freeze({ mid = 60, high = 100, jackpot = 160 }),
	APPRAISE_COUNT = 14,
	APPRAISE_COLOR = Color3.fromRGB(244, 236, 216),
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
	-- The load floaters: life, rise, spacing between two, draw distance, design size in px (CargoLoadFloater).
	FLOATER_SECONDS = 1.4,
	FLOATER_RISE = 4,
	FLOATER_SPACING = 1.3,
	FLOATER_DISTANCE = 150,
	FLOATER_PX = Vector2.new(340, 130),
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
