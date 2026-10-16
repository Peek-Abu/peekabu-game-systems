--!strict
--[=[
	HideConstants: hiding spots (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §4). Players hide
	under desks and tables and inside lockers and filing cabinets: the office's own furniture, tagged by Office as it
	builds it. Every number is a tuning hypothesis. Static data (spec-exempt).

	@class HideConstants
]=]

export type FurnitureKind = "desk" | "table" | "locker" | "cabinet"

-- What each piece of furniture offers: hiding under it or inside it, the prompt's verb and noun.
export type FurnitureDef = { spot: "under" | "inside", action: string, noun: string }

local function furniture(spot: "under" | "inside", action: string, noun: string): FurnitureDef
	local def: FurnitureDef = { spot = spot, action = action, noun = noun }
	return table.freeze(def)
end

local FURNITURE: { [string]: FurnitureDef } = {
	desk = furniture("under", "Hide under", "desk"),
	table = furniture("under", "Hide under", "table"),
	locker = furniture("inside", "Hide in", "locker"),
	cabinet = furniture("inside", "Hide in", "cabinet"),
}
return table.freeze({
	-- Office tags every desk, table, locker and filing cabinet it builds, naming its kind.
	FURNITURE_TAG = "HideFurniture",
	FURNITURE_KIND_ATTRIBUTE = "HideFurnitureKind",
	FURNITURE = table.freeze(FURNITURE),
	-- Each piece's spot: an Attachment on its front (local -Z, where the drawers, door and knee-hole are) holding the
	-- hold-to-enter prompt, tagged, with its id, its kind and the peek camera (a world CFrame) as attributes.
	SPOT_NAME = "HideSpot",
	SPOT_TAG = "HideSpot",
	SPOT_ID_ATTRIBUTE = "HideSpotId",
	SPOT_KIND_ATTRIBUTE = "HideSpotKind",
	SPOT_NOUN_ATTRIBUTE = "HideSpotNoun",
	PEEK_ATTRIBUTE = "HidePeek",
	PROMPT_NAME = "HidePrompt",
	-- The prompt: its own key (C / L1, so it never takes E from Search), held ENTER_HOLD seconds within ENTER_RANGE.
	ACTION = "hide",
	KEYBOARD_KEY = Enum.KeyCode.C,
	GAMEPAD_KEY = Enum.KeyCode.ButtonL1,
	ENTER_HOLD = 0.6,
	ENTER_RANGE = 6,
	-- The server allows this much more than ENTER_RANGE (the player moved while holding).
	RANGE_TOLERANCE = 3,
	-- Replicated on the hiding Player: the spot's id, and when they went in (server time).
	PLAYER_SPOT_ATTRIBUTE = "HideSpotId",
	PLAYER_SINCE_ATTRIBUTE = "HideSince",
	-- Anti-camping: after CAMP_WARN_SECONDS in one spot the chip warns "cramped"; at CAMP_SECONDS they are pushed out,
	-- and that spot refuses them for SPOT_COOLDOWN_SECONDS.
	CAMP_WARN_SECONDS = 20,
	CAMP_SECONDS = 30,
	SPOT_COOLDOWN_SECONDS = 10,
	-- A hand item small enough to hide with (a pocketable tiny item); anything bigger stops you.
	POCKETABLE_SIZE = "tiny",
	-- The body in the spot: the head's top stands about HEAD_ABOVE_ROOT above the root; under furniture it is sunk so
	-- that top clears the underside by UNDER_CLEARANCE (the legs go below the floor, out of sight).
	HEAD_ABOVE_ROOT = 2.6,
	UNDER_CLEARANCE = 0.4,
	-- Where the exit puts you: this far out in front of the furniture (or behind, or beside, when that is blocked).
	EXIT_GAP = 2.4,
	EXIT_PROBE = Vector3.new(2, 4.5, 2),
	-- The peek camera: its priority (above play, below Death's spectate at 50), field of view, and how far the mouse
	-- may look around (degrees either way).
	PEEK_PRIORITY = 45,
	PEEK_FOV = 62,
	PEEK_YAW = 35,
	PEEK_PITCH = 12,
	-- The peek view's height: under furniture, low by the front edge; inside, at eye height in the door's slits.
	UNDER_EYE = 1.3,
	INSIDE_EYE_FROM_TOP = 1.1,
	-- Exit requests are rate limited.
	EXIT_RATE = table.freeze({ maxRequests = 10, windowSeconds = 5 }),
})
