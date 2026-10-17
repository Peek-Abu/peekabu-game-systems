--!strict
--[=[
	HideConstants: hiding spots (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §4). Players hide
	under desks and tables, and inside the tall supply cabinets (2026-10-16: always closed, so no open/closed state; the
	secure spot the Manager must open): the office's own furniture, tagged by Office as it builds it. Every number is a tuning hypothesis. Static data (spec-exempt).

	@class HideConstants
]=]

export type FurnitureKind = "desk" | "table" | "cabinet"

-- Where the tucked body lies under a piece of furniture (its spot's frame): the root `along` its length (+X) and
-- `back` (+Z) from its centre, turned `yaw` degrees from facing out of the front.
export type Tuck = { along: number, back: number, yaw: number }

-- What each piece of furniture offers: hiding under it (desks and tables) or inside it (the tall supply cabinet, always
-- closed; lockers and filing cabinets stay out: a locker's open and closed states made it unreliable, a filing cabinet
-- is too small), the prompt's verb and noun, where the body lies (or stands), and whether the spot may face the
-- furniture's back when that is the more open side (a table; a desk's knee-hole and a cabinet's door are always its
-- front).
export type FurnitureDef = { spot: "under" | "inside", action: string, noun: string, tuck: Tuck, turnable: boolean }

-- One joint of the tucked pose: its Motor6D's name, the rotation (degrees about the joint's X, Y, Z) and an offset.
export type PoseJoint = { joint: string, rotation: Vector3, offset: Vector3 }

local function furniture(noun: string, tuck: Tuck, turnable: boolean): FurnitureDef
	local def: FurnitureDef =
		{ spot = "under", action = "Hide under", noun = noun, tuck = table.freeze(tuck), turnable = turnable }
	return table.freeze(def)
end

local function closet(noun: string, tuck: Tuck): FurnitureDef
	local def: FurnitureDef =
		{ spot = "inside", action = "Hide in", noun = noun, tuck = table.freeze(tuck), turnable = false }
	return table.freeze(def)
end

local FURNITURE: { [string]: FurnitureDef } = {
	-- A desk's drawer pedestal fills its +X end: the curled body lies corner to corner across the knee-hole (about
	-- 3.5 by 3), head toward the front-left corner.
	desk = furniture("desk", { along = -0.1, back = 0.55, yaw = 49 }, false),
	-- A table is open underneath: the body lies along its length.
	table = furniture("table", { along = 1.1, back = 0.2, yaw = 90 }, true),
	-- The tall supply cabinet: standing upright in the middle, a little back from the door, facing out of it.
	cabinet = closet("cabinet", { along = 0, back = 0.25, yaw = 0 }),
}

local function pose(joint: string, rotation: Vector3, offset: Vector3?): PoseJoint
	local entry: PoseJoint = { joint = joint, rotation = rotation, offset = offset or Vector3.zero }
	return table.freeze(entry)
end

-- The tucked huddle under the desk, on the employee rig (R15 joints, arms T-posed in the rig): kneeling on the heels,
-- the torso folded down over the knees, the head bowed (the ears, which Employee's ear system owns, follow it forward
-- and low) and the arms tucked along the body. The body lies along the desk's length, so it fits under the desktop.
-- Tuned live in Studio.
local TUCK_POSE: { PoseJoint } = {
	pose("Root", Vector3.new(0, 0, 0), Vector3.new(0, -0.55, 0)),
	pose("LeftHip", Vector3.new(95, 0, 0)),
	pose("RightHip", Vector3.new(95, 0, 0)),
	pose("LeftKnee", Vector3.new(-165, 0, 0)),
	pose("RightKnee", Vector3.new(-165, 0, 0)),
	pose("LeftAnkle", Vector3.new(60, 0, 0)),
	pose("RightAnkle", Vector3.new(60, 0, 0)),
	pose("Waist", Vector3.new(-75, 0, 0)),
	pose("Neck", Vector3.new(-55, 0, 0)),
	pose("LeftShoulder", Vector3.new(0, 0, 80)),
	pose("RightShoulder", Vector3.new(0, 0, -80)),
	pose("LeftElbow", Vector3.new(0, 30, 0)),
	pose("RightElbow", Vector3.new(0, -30, 0)),
}

return table.freeze({
	-- Office tags every desk and table it builds, naming its kind.
	FURNITURE_TAG = "HideFurniture",
	FURNITURE_KIND_ATTRIBUTE = "HideFurnitureKind",
	FURNITURE = table.freeze(FURNITURE),
	-- Each piece's spot: an Attachment on its front (local -Z, the knee-hole side) holding the press-to-enter prompt,
	-- tagged, with its id, its kind and the peek camera (a world CFrame) as attributes.
	SPOT_NAME = "HideSpot",
	SPOT_TAG = "HideSpot",
	SPOT_ID_ATTRIBUTE = "HideSpotId",
	SPOT_KIND_ATTRIBUTE = "HideSpotKind",
	SPOT_NOUN_ATTRIBUTE = "HideSpotNoun",
	PEEK_ATTRIBUTE = "HidePeek",
	PROMPT_NAME = "HidePrompt",
	-- The prompt: its own key (C / L1, so it never takes E from Search), a single press within ENTER_RANGE.
	ACTION = "hide",
	KEYBOARD_KEY = Enum.KeyCode.C,
	GAMEPAD_KEY = Enum.KeyCode.ButtonL1,
	ENTER_HOLD = 0,
	ENTER_RANGE = 6,
	-- The server allows this much more than ENTER_RANGE (the player moved as they pressed).
	RANGE_TOLERANCE = 3,
	-- Snappy: the body slides into the spot in TUCK_SECONDS (and the pose folds in as fast); out, it unfolds in
	-- UNTUCK_SECONDS. Anti-spam: a stay lasts at least MIN_STAY_SECONDS, and after coming out a player waits
	-- REENTER_SECONDS before going into any spot.
	TUCK_SECONDS = 0.25,
	UNTUCK_SECONDS = 0.2,
	MIN_STAY_SECONDS = 0.5,
	REENTER_SECONDS = 1,
	-- Replicated on the hiding Player: the spot's id, and when they went in (server time).
	PLAYER_SPOT_ATTRIBUTE = "HideSpotId",
	PLAYER_SINCE_ATTRIBUTE = "HideSince",
	-- Anti-camping: after CAMP_WARN_SECONDS in one spot the chip warns "cramped"; at CAMP_SECONDS they are pushed out,
	-- and that spot refuses them for SPOT_COOLDOWN_SECONDS.
	CAMP_WARN_SECONDS = 20,
	CAMP_SECONDS = 30,
	SPOT_COOLDOWN_SECONDS = 10,
	-- Coming out is heard (the Manager's behaviours design §10.3; NoiseServiceServer relays it): leaving yourself makes a
	-- small noise of EXIT_NOISE studs, being pushed out cramped a "tumble out" of CRAMPED_NOISE (and the tumble sound,
	-- HideAssets.TUMBLE, to everyone within TUMBLE_SOUND_RADIUS). Evicted, caught or gone: no noise.
	EXIT_NOISE = 9,
	CRAMPED_NOISE = 19,
	TUMBLE_SOUND_RADIUS = 60,
	-- The hand items small enough to hide with (the hotbar's small sizes: tiny and light); a big item stops you.
	POCKETABLE_SIZES = table.freeze({ tiny = true, light = true }),
	-- The body under the furniture: the root stands where a standing root would (the pose folds the body down), placed
	-- by its FurnitureDef's tuck (TUCK_POSE).
	TUCK_POSE = table.freeze(TUCK_POSE),
	-- A spot faces the room: its furniture is turned half round when its back has more than OPEN_MARGIN studs more
	-- open floor than its front, looked for out to OPEN_PROBE studs.
	OPEN_MARGIN = 1,
	OPEN_PROBE = 30,
	-- Where the exit puts you: this far out in front of the furniture (or behind, or beside, when that is blocked).
	EXIT_GAP = 2.4,
	EXIT_PROBE = Vector3.new(2, 4.5, 2),
	-- The peek camera: its priority (above play, below Death's spectate at 50), field of view, and how far the mouse
	-- may look around (degrees either way).
	PEEK_PRIORITY = 45,
	PEEK_FOV = 62,
	PEEK_YAW = 35,
	PEEK_PITCH = 12,
	-- The peek view's height: low by the furniture's front edge; inside a cabinet, at the door's louvre band (the
	-- supplyCabinet art: louvres 5.0-6.2 over its floor).
	UNDER_EYE = 1.3,
	INSIDE_EYE = 5.55,
	-- A cabinet's door, swung open by the Manager when he checks it (HideServiceServer:setDoor): the furniture's
	-- attribute, the art's door part, how far it swings (degrees) and how long; a DOOR_RATTLE second rattle first.
	DOOR_OPEN_ATTRIBUTE = "HideDoorOpen",
	DOOR_PART = "Door",
	DOOR_SWING = 105,
	DOOR_SECONDS = 0.5,
	DOOR_RATTLE = 0.9,
	-- Exit requests are rate limited.
	EXIT_RATE = table.freeze({ maxRequests = 10, windowSeconds = 5 }),
})
