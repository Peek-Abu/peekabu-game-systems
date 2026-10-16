--!strict
--[=[
	HideTypes: the Hide feature's shapes (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §4). Types
	only (spec-exempt).

	@class HideTypes
]=]

-- Under a desk or table (the only kind today; kept named for the behaviours to come).
export type SpotKind = "under"

-- Where a spot puts things (world space): the hiding root, the peek camera, and the exits to try in order.
export type SpotFrames = {
	hide: CFrame,
	peek: CFrame,
	-- The prompt's offset in the furniture's own space.
	prompt: Vector3,
	exits: { CFrame },
}

-- One hiding spot, as the server keeps it.
export type Spot = {
	id: string,
	kind: SpotKind,
	-- "desk" or "table".
	noun: string,
	furniture: BasePart,
	-- The spot's frame: the furniture's, turned to face the room (HideSpotUtils.spotFrame).
	frame: CFrame,
	-- The prompt's attachment.
	anchor: Attachment,
}

-- A player in a spot: since when (os.clock), and whether the Manager saw them go in.
export type Occupancy = {
	spotId: string,
	since: number,
	seenEntering: boolean,
}

-- Why someone left a spot: they chose to, they were pushed out (camping), forced out by a rule (`evict`), or the
-- spot or their character went away.
export type ExitReason = "left" | "cramped" | "evicted" | "gone"

-- What a would-be entry is checked against (HideRules.canEnter).
export type EnterInput = {
	alive: boolean,
	hidden: boolean,
	catching: boolean,
	-- The size of the hand item ("tiny", "medium", ...), nil when empty-handed.
	heldSize: string?,
	occupied: boolean,
	cooling: boolean,
	-- REENTER_SECONDS have passed since their last stay ended.
	rested: boolean,
	distance: number,
}

-- What the public API answers about a hiding player.
export type SpotInfo = {
	id: string,
	kind: SpotKind,
	noun: string,
	furniture: BasePart,
	position: Vector3,
	since: number,
	seenEntering: boolean,
}

return {}
