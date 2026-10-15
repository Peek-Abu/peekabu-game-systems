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
		-- Once, when the player banked any salvage during overtime.
		overtimeSalvage = 5,
		-- With the crew at the end and never caught.
		extracted = 5,
		-- Each, when the whole crew extracted.
		crewExtracted = 5,
	}),

	-- The results card's breakdown label for each award (short: the whole breakdown is one typed line).
	LABELS = table.freeze({
		shiftWorked = "Shift",
		quotaMet = "Quota",
		items = "Cargo",
		overtimeSalvage = "Overtime salvage",
		extracted = "Clocked out",
		crewExtracted = "Whole crew out",
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
