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
}

return table.freeze(DepotSpotConstants)
