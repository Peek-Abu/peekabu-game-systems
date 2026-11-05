--!strict
--[=[
	RankConstants: the company rank's switches and XP table (Cleanup Crew "Clearance Level", docs/cleanup-crew-rank.md).

	THE TWO RESET SWITCHES — both are one-line edits, nothing else to touch:

	- RANK_SEASON: every saved rank carries the season it was earned in. When a player joins and their stored season
	  differs from this constant, their rank resets to level 1 / 0 XP (RankRules.reconcileSeason). Bump it (for example
	  "mvp-1" -> "mvp-2") to wipe everyone's rank on their next join, with no DataStore edits or migration.
	- RANK_PERSIST: true saves the rank in the player's profile (the `rank` account slice). false keeps it in server
	  memory only for the session: nothing is written to the profile, and it starts at level 1 on every join.

	Studio note: Studio Play uses ProfileStore's mock store (ServerHandler `useMock = RunService:IsStudio()`), so
	ranks never survive a Studio session either way; persistence only happens in published servers.

	@class RankConstants
]=]

local RankConstants = {
	-- Bump to reset every player's rank on their next join (see the header).
	RANK_SEASON = "mvp-1",
	-- false = session-only rank, never written to the profile (see the header).
	RANK_PERSIST = true,

	-- XP per shift, awarded once per player by the server when the shift's review is published.
	XP = table.freeze({
		shiftWorked = 10,
		quotaMet = 15,
		-- Per cargo item the player banked themselves, up to `itemCap` items.
		perItem = 1,
		itemCap = 10,
		-- Once, when the player banked any overtime loot (the shimmering batch Office spawns when overtime begins).
		overtimeSalvage = 5,
		-- With the crew at the end and never caught.
		extracted = 5,
		-- Each, when the whole crew extracted.
		crewExtracted = 5,
		-- The shift's XP is multiplied by this when another crew member is a Roblox friend (the "friends" line adds
		-- the difference).
		friendMultiplier = 2,
	}),

	-- A shift counts as worked (RankFormulas.worked) only when it ran at least this long, unless the contract was
	-- made. The one knob for the clock-out farm (docs/superpowers/specs/2026-11-04-worked-shift-rule-design.md).
	MIN_WORKED_SECONDS = 180,

	-- The results card's breakdown label for each award (short: the whole breakdown is one typed line).
	LABELS = table.freeze({
		shiftWorked = "Shift",
		quotaMet = "Contract",
		items = "Cargo",
		overtimeSalvage = "Overtime loot",
		extracted = "Clocked out",
		crewExtracted = "Whole crew out",
		friends = "Friends x2",
	}),
	INCIDENT_LINE = "Incident Report filed",

	-- The public-entry fields every client reads a player's rank from (the results card): the XP now, and
	-- the XP before the latest award (equal to it after a load), which tells the card a promotion has landed.
	PUBLIC_XP_FIELD = "rankXp",
	PUBLIC_PREV_XP_FIELD = "rankPrevXp",

	-- Data-layer limits (RankRules.validate).
	MAX_XP = 10000000,
	MAX_SEASON_LENGTH = 32,
	MAX_RUN_ID_LENGTH = 64,
}

return table.freeze(RankConstants)
