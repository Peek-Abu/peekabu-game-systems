--!strict
--[=[
	DepotSpotConstants: the hub's spots (owner's picks, 2026-11-11; plan docs/superpowers/plans/2026-11-11-hub-interactables.md).
	A spot is a Studio part with the base Interaction tag and `InteractionKind` set to one of KINDS; a standee also
	carries EMPLOYEE_ATTRIBUTE. The prompt words are for young players. The radio's stations, the bell's cooldown and
	the delivery truck that drives past the yard (DRIVE_BY) live here too. Static data (spec-exempt).

	@class DepotSpotConstants
]=]

export type Spot = "shop" | "standee" | "coffee" | "crew" | "rank" | "radio" | "bell" | "locker"

export type Station = {
	-- The toast's words.
	name: string,
	-- The registered music id it plays (DepotAssets), or nil for a quiet station.
	track: string?,
}

-- Interaction kind (the InteractionKind attribute in Studio) per spot.
local KINDS: { [string]: string } = table.freeze({
	shop = "depot-spot-shop",
	standee = "depot-spot-standee",
	coffee = "depot-spot-coffee",
	crew = "depot-spot-crew",
	rank = "depot-spot-rank",
	radio = "depot-spot-radio",
	bell = "depot-spot-bell",
	locker = "depot-spot-locker",
})

-- The prompt per spot: its verb and noun (a standee's noun is replaced by the employee's name).
local PROMPTS: { [string]: { action: string, object: string } } = table.freeze({
	shop = table.freeze({ action = "Shop", object = "Supply Counter" }),
	standee = table.freeze({ action = "Meet", object = "Crew member" }),
	coffee = table.freeze({ action = "Coffee", object = "Coffee machine" }),
	crew = table.freeze({ action = "Look", object = "Top crews" }),
	rank = table.freeze({ action = "Look", object = "Rank chart" }),
	radio = table.freeze({ action = "Next song", object = "Radio" }),
	bell = table.freeze({ action = "Ring", object = "Shift bell" }),
	-- A Lost & Found locker door (its noun is the door's LABEL_ATTRIBUTE: "Gloom Locker" or "Gleam Locker").
	locker = table.freeze({ action = "Open", object = "Locker" }),
})

local STATIONS: { Station } = {
	table.freeze({ name = "Garage Tunes", track = "depotHubTheme" }),
	table.freeze({ name = "Quiet Night", track = nil }),
}

-- Seconds between an idle motion's goes (min, max), by motion (IDLE below).
local IDLE_INTERVALS: { [string]: { number } } = {
	steam = { 3, 6 },
	drip = { 2, 4 },
	sway = { 9, 16 },
	rattle = { 7, 14 },
	twinkle = { 4, 8 },
	candrop = { 12, 22 },
}

local DepotSpotConstants = {
	KINDS = KINDS,
	PROMPTS = PROMPTS,
	-- A standee names its employee (EmployeeRegistry name) here.
	EMPLOYEE_ATTRIBUTE = "DepotEmployee",
	-- Any spot may name itself on its prompt (a locker door: "Gloom Locker").
	LABEL_ATTRIBUTE = "DepotLabel",
	-- The Shop tab a locker door opens.
	LOCKER_TAB = "lockers",
	-- Studs: how close a player must stand (the server checks it too).
	MAX_DISTANCE = 9,
	-- Seconds one player waits before using the same spot again (the Interaction feature's cooldown).
	USE_COOLDOWN = 0.75,
	-- Seconds a bell rests after it rings, for everyone (so a crew can't spam it).
	BELL_COOLDOWN = 2.5,
	-- The registered bell sound (DepotAssets), played at the bell on every client.
	BELL_SOUND = "depotShiftBell",
	STATIONS = table.freeze(STATIONS),
	-- The bell's swing when it rings (DepotSpotRules.bellSwing): its parts with SWING_ATTRIBUTE swing about the
	-- attachment PIVOT_NAME (on the bell's arm), DEGREES at most, dying down over SECONDS at FREQUENCY swings a second.
	-- A gold ring wave puffs out from the bell (RING_*).
	BELL_SWING = table.freeze({
		SWING_ATTRIBUTE = "DepotSwing",
		PIVOT_NAME = "BellPivot",
		DEGREES = 38,
		SECONDS = 1.6,
		FREQUENCY = 2.4,
		DAMPING = 2.6,
		RING_SECONDS = 0.55,
		RING_SIZE = 9,
		RING_COLOR = Color3.fromRGB(255, 205, 80),
	}),
	-- The radio's music notes (DepotSpotRules.noteRate): notes a second on a station with music.
	RADIO_NOTES = table.freeze({
		RATE = 1.6,
		-- The radio part that emits them (in the tagged radio model).
		EMITTER_NAME = "RadioBody",
	}),
	-- The coffee scene's words.
	COFFEE_LINE = "2x pay on your next shift!",
	-- The scenes the client opens.
	SCENES = table.freeze({
		coffee = "depot.Coffee",
		crew = "depot.CrewWall",
		rank = "depot.RankChart",
	}),
	-- The delivery truck outside: a road of parts tagged TAG with Order = 1..N; a truck drives it every
	-- MIN_GAP..MAX_GAP seconds at SPEED studs/s and honks once on the way.
	DRIVE_BY = table.freeze({
		TAG = "DepotDriveBy",
		ORDER_ATTRIBUTE = "Order",
		-- The truck itself: one Model with this tag, parked out of sight at the road's start, its pivot facing
		-- forward. Each client drives its own copy (anchored parts moved locally), so nothing replicates.
		VEHICLE_TAG = "DepotDriveByVehicle",
		MIN_GAP = 35,
		MAX_GAP = 75,
		SPEED = 26,
		HORN_SOUND = "depotDriveByHorn",
		-- The chance the truck honks on a pass.
		HORN_CHANCE = 0.5,
	}),
	-- The Supply Counter clerk (DepotClerkSystem, DepotClerkRules; owner 11-11 "Stamp & Stack"): Pippa (she ran the
	-- front desk before night shifts) stands on the part tagged TAG (facing its LookVector) behind the counter in an
	-- active idle (DepotAssets.CLERK_IDLE), breaking into a fidget every FIDGET_MIN..FIDGET_MAX seconds: one of FIDGETS
	-- by weight (a one-off, `again` false, never twice in a row). She waves when a player comes near.
	CLERK = table.freeze({
		TAG = "DepotClerkSpot",
		EMPLOYEE = "Pippa",
		FIDGET_MIN = 3,
		FIDGET_MAX = 7,
		FIDGETS = table.freeze({
			table.freeze({ name = "stamp", weight = 3, again = true }),
			table.freeze({ name = "stretch", weight = 1, again = false }),
		}),
		-- The clip markers the code acts on: the stamp lands (the parcel squashes), the stamp lifts (the parcel hops).
		THUNK_MARKER = "Thunk",
		LIFT_MARKER = "Lift",
		-- When the stamp is on the parcel in the clip (seconds): where the parcel's height is measured.
		CONTACT_TIME = 24 / 30,
		-- Studs from the clerk a player walks up to get a wave; seconds before the next wave.
		GREET = table.freeze({ RADIUS = 12, COOLDOWN = 20 }),
		-- The parcel's hop after the stamp lifts: a beat (DELAY), up APEX studs and back down over SECONDS, then it
		-- lands squashed to SQUASH of its height for SQUASH_SECONDS.
		HOP = table.freeze({ DELAY = 0.08, APEX = 0.4, SECONDS = 0.3, SQUASH = 0.85, SQUASH_SECONDS = 0.1 }),
		-- The parcel: its footprint (studs) and the height range that still reads as a parcel.
		PARCEL = table.freeze({
			WIDTH = 0.95,
			DEPTH = 0.75,
			MIN_HEIGHT = 0.15,
			MAX_HEIGHT = 1.0,
			TAPE_WIDTH = 0.22,
			COLOR = Color3.fromRGB(196, 150, 98),
			TAPE_COLOR = Color3.fromRGB(232, 208, 150),
		}),
		-- The rubber stamp in the clerk's right hand: a red base under a wooden handle and knob, upright in the fist so
		-- its face is flat on the parcel at the contact (GRIP: the handle's offset in RightHand space at a scale of 1,
		-- solved on Pippa at the v6 stamp's contact frame so the handle stands straight up, owner 11-11: "stamp not
		-- held properly").
		STAMP = table.freeze({
			BASE = Vector3.new(0.42, 0.12, 0.3),
			HANDLE_LENGTH = 0.32,
			HANDLE_WIDTH = 0.12,
			KNOB = 0.2,
			BASE_COLOR = Color3.fromRGB(214, 48, 49),
			WOOD_COLOR = Color3.fromRGB(120, 78, 45),
			GRIP_POSITION = Vector3.new(0, 0, 0),
			GRIP_DEGREES = Vector3.new(-14.6, -59.4, -22.6),
		}),
	}),
	-- The stations' small idle motions (DepotIdleMotionSystem, DepotIdleRules; owner 11-11, ideas sheet #3). A builder
	-- tags any part TAG and names its motion in ATTRIBUTE: "steam" (puffs from the part's top), "drip" (a drop falls
	-- from its bottom), "bounce" (its model hops on the beat while the radio plays music), "sway" (its model's swing
	-- parts nudge about the bell pivot), "rattle" (the part jiggles about its left edge, a locker door), "twinkle"
	-- (gold sparkles round it), "candrop" (a can falls inside it, a vending window), "tick" (a second hand on its front
	-- face, a clock). INTERVALS: seconds between goes (min, max) for the ones that come and go.
	-- The break room's sleepy employee (DepotLoungeSystem, DepotLoungeRules; owner 11-11, ideas sheet #4): EMPLOYEE dozes
	-- sitting on the part tagged TAG (a sofa cushion, facing its LookVector) and wakes to wave when a player walks within
	-- WAKE_RADIUS studs, at most once every COOLDOWN seconds.
	LOUNGE = table.freeze({
		TAG = "DepotLoungeSpot",
		EMPLOYEE = "Cappy",
		-- The face he sleeps in (owner 11-12: his eyes were open while napping): a closed-eyes face from the model's Faces
		-- folder (every employee has this one); he wears his own default face while he is awake to wave.
		SLEEP_FACE = "RevealBlinkClosed",
		WAKE_RADIUS = 10,
		COOLDOWN = 25,
	}),
	-- The stations' toppers (DepotTopperSystem, DepotTopperRules; owner 11-12, kit mock round 2 #1, ideas #5 and #6). A
	-- builder places a thin part tagged TAG with ATTRIBUTE naming its station (a key of DepotTopperConstants.STATIONS);
	-- its LookVector faces the readers and its width sets the topper's size (PLATE.X wide = 1x, so a builder resizes the
	-- anchor to resize the topper). The client stands a kit plate there (PLATE studs, drawn at PIXELS_PER_STUD), a
	-- backing behind it, a warm light pool under it (POOL) and the station's lane on the floor in front (LANE: from
	-- LANE_START_ATTRIBUTE studs ahead of the anchor, LANE_LENGTH_ATTRIBUTE long; defaults below). The time clock and
	-- the daily sheet are built by the server, so their toppers stand on their sign shells (SHELL_GAP above the top).
	TOPPER = table.freeze({
		TAG = "DepotTopper",
		ATTRIBUTE = "Topper",
		LANE_START_ATTRIBUTE = "LaneStart",
		LANE_LENGTH_ATTRIBUTE = "LaneLength",
		-- The topper's canvas (studs): the plate at the bottom, the icon breaking out of its top edge above it.
		PLATE = Vector2.new(2.8, 2.1),
		-- The plate body's share of the canvas height (the backing covers just the body).
		BODY_SHARE = 0.5,
		PIXELS_PER_STUD = 100,
		SHELL_GAP = 0.05,
		POOL = table.freeze({
			COLOR = Color3.fromRGB(255, 196, 120),
			BRIGHTNESS = 1.6,
			ANGLE = 70,
			-- Studs past the floor the light reaches, at least MIN_RANGE.
			REACH = 2,
			MIN_RANGE = 6,
		}),
		LANE = table.freeze({
			START = 2,
			LENGTH = 6,
			WIDTH = 1.6,
			THICKNESS = 0.02,
			-- Studs above the floor, so the lane never flickers with the floor paint.
			LIFT = 0.012,
			-- How far below the anchor the floor is looked for.
			PROBE = 40,
			CHEVRONS = 3,
		}),
		-- The outline on the station the prompt picked (ideas #6): soft, only while looked at.
		OUTLINE = table.freeze({
			TRANSPARENCY = 0.25,
			FADE = 0.15,
		}),
	}),
	IDLE = table.freeze({
		TAG = "DepotIdleMotion",
		ATTRIBUTE = "IdleMotion",
		-- The hub record: 96 bpm.
		BEAT_SECONDS = 60 / 96,
		BOUNCE = table.freeze({ APEX = 0.06, SHARE = 0.35 }),
		RATTLE = table.freeze({ DEGREES = 3, FREQUENCY = 9, DAMPING = 5, SECONDS = 0.6 }),
		SWAY = table.freeze({ DEGREES = 5, FREQUENCY = 1.3, SECONDS = 1.8 }),
		FALL = table.freeze({ GRAVITY = 40, DISTANCE = 1.2 }),
		-- The vending machine's "candrop" (owner 11-12): one of the stocked items (parts tagged STOCK_TAG inside the
		-- marker part's box) is nudged PUSH studs forward off its shelf over PUSH_SECONDS, drops to the marker's bottom
		-- (the tray), tipping TIP degrees, rests REST seconds, and is back on its shelf (local only).
		VEND = table.freeze({
			STOCK_TAG = "DepotVendingStock",
			PUSH = 0.3,
			PUSH_SECONDS = 0.35,
			TIP = 75,
			REST = 1.2,
		}),
		-- The time clock art's dial part: the hub's clock (built by the server) tags it "tick" so its second hand turns.
		CLOCK_DIAL = "ClockFace",
		INTERVALS = table.freeze(IDLE_INTERVALS),
	}),
}

return table.freeze(DepotSpotConstants)
