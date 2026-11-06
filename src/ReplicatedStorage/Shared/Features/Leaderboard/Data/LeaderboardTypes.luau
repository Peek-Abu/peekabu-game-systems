--!strict
--[=[
	LeaderboardTypes: the weekly crew board's shapes.

	@class LeaderboardTypes
]=]

-- A crew's members (sorted user ids) and their display names when the score was set.
export type Roster = {
	ids: { number },
	names: { string },
}

-- One row of the board: the crew's names and its best Gloom removed in one shift this week.
export type Entry = {
	names: { string },
	score: number,
}

-- What a hub server publishes (the `crewBoard` world entry): the week's Monday ("2026-11-02"), when it ends (Unix
-- seconds) and the rows, best first.
export type Board = {
	week: string,
	endsAt: number,
	entries: { Entry },
}

return {}
