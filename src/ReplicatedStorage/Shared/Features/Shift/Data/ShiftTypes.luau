--!strict
--[=[
	ShiftTypes: one Cleanup Crew shift's shapes (spec §3, §6.3, §6.5). Types only (spec-exempt).

	@class ShiftTypes
]=]

-- Mirrors Round's phases, except that Shift holds `results` itself until the crew votes.
export type ShiftPhase = "lobby" | "starting" | "running" | "results"

-- What a running shift is doing. M2 adds "break" | "warning" | "overtime".
export type ShiftSub = "normal" | "clockout"

-- The A/B validation switch (spec §4): B hides some salvage under piles, A exposes it all.
export type Variant = "A" | "B"

export type Vote = "another" | "depot"

-- What the service should do on this clock step.
export type TickAction = "none" | "start" | "endShift" | "resolveVote"

-- The server's shift machine. Times are server time (workspace:GetServerTimeNow()).
export type ShiftState = {
	phase: ShiftPhase,
	sub: ShiftSub,
	-- Shifts started on this server (Round's run number).
	shift: number,
	-- starting: the arrival countdown's end; running: the shift's end.
	endsAt: number?,
	-- When the clock-out countdown ends the shift.
	clockOutAt: number?,
	-- When the results vote closes.
	voteEndsAt: number?,
	quota: number,
	quotaMet: boolean,
	variant: Variant,
}

-- One crew member's run, as the results builder reads it.
export type CrewStats = {
	userId: number,
	name: string,
	banked: number,
	piles: number,
	salvage: number,
}

export type CrewLine = {
	name: string,
	banked: number,
	piles: number,
	salvage: number,
}

export type Award = {
	title: string,
	name: string,
}

-- The performance review (plain in M1).
export type ShiftResults = {
	outcome: string,
	quota: number,
	cleared: number,
	bonus: number,
	-- Salvage items loaded, and piles vacuumed, by the whole crew.
	salvage: number,
	piles: number,
	quotaMet: boolean,
	crew: { CrewLine },
	awards: { Award },
}

-- What every client sees (the `shift` world entry).
export type ShiftSnapshot = {
	phase: ShiftPhase,
	sub: ShiftSub,
	shift: number,
	endsAt: number?,
	clockOutAt: number?,
	voteEndsAt: number?,
	quota: number,
	cleared: number,
	bonus: number,
	quotaMet: boolean,
	variant: Variant,
	votesAnother: number,
	votesDepot: number,
	results: ShiftResults?,
}

return {}
