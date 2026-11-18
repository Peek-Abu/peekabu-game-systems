--!strict
--[=[
	SkillCheckTypes: the closing-ring skill check's shapes. Types only (spec-exempt).

	@class SkillCheckTypes
]=]

-- One ring, as the server decides it and its player's client draws it. Angles are screen degrees (0 = straight up,
-- clockwise); `arriveAt` is on the server clock (workspace:GetServerTimeNow), `travel` seconds after it started.
export type Ring = {
	id: number,
	-- The opening's centre and full width.
	gap: number,
	width: number,
	arriveAt: number,
	travel: number,
}

-- The server's judgement of one ring for one player.
export type Verdict = {
	userId: number,
	ring: Ring,
	hit: boolean,
}

-- What a client reports at a ring's arrival: the ring and where its icon was.
export type Report = {
	id: number,
	angle: number,
}

return {}
