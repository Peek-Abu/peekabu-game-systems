--!strict
--[=[
	ShiftTypes: one Cleanup Crew shift's shapes (spec §3, §4 "Pacing", §6.3, §6.5). Types only (spec-exempt).

	@class ShiftTypes
]=]

-- Mirrors Round's phases, except that Shift holds `results` itself until the crew votes.
export type ShiftPhase = "lobby" | "starting" | "running" | "results"

-- The clock-out countdown. Independent of the pacing stage: a crew may clock out during the break or overtime.
export type ShiftSub = "normal" | "clockout"

-- Pacing after the quota (spec §4 "Pacing"): break (Harlow rests) → overtime warning → overtime.
export type ShiftStage = "normal" | "break" | "warning" | "overtime"

-- The A/B validation switch (spec §4): B hides some salvage under piles, A exposes it all.
export type Variant = "A" | "B"

-- How each shift's variant is chosen (ShiftVariantRules): "alternate" flips A/B every shift from a per-server start;
-- "fixed" always plays ShiftConstants.VARIANT.
export type VariantMode = "alternate" | "fixed"

-- Where a shift's variant came from: the alternation, the fixed default, or the developer's Workspace override.
export type VariantSource = "alternate" | "fixed" | "override"

-- The device a client reports for analytics (ShiftPlatformRules accepts only pc/phone/tablet/console from a client);
-- "unknown" until a valid report arrives.
export type Platform = "pc" | "phone" | "tablet" | "console" | "unknown"

export type Vote = "another" | "depot"

-- What the service should do on this clock step.
export type TickAction = "none" | "start" | "endShift" | "resolveVote"

-- The server's shift machine. Times are server time (workspace:GetServerTimeNow()).
export type ShiftState = {
	phase: ShiftPhase,
	sub: ShiftSub,
	stage: ShiftStage,
	-- When the break or the warning ends; nil in the normal stage and in overtime.
	stageEndsAt: number?,
	-- Pressure tier: 0, +1 at each ShiftConstants.TIER_TIMES mark, the top tier in overtime.
	tier: number,
	-- Shifts started on this server (Round's run number).
	shift: number,
	-- running: when the shift began (the tiers count from here).
	startedAt: number?,
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

-- The performance review's overall stamp (Figma 35:1096): quota missed, met, or met with the salvage threshold.
export type Rating = "needsImprovement" | "satisfactory" | "exceeds"

-- One crew member's run, as the results builder reads it.
export type CrewStats = {
	userId: number,
	name: string,
	banked: number,
	piles: number,
	salvage: number,
	-- Times Mr. Harlow caught them (M2); absent reads 0.
	caught: number?,
	-- M3 UI (the joke awards): drops by hand (and throws of fragile items), noises made, times Harlow went to
	-- investigate a noise they made, and the most valuable item they dropped (its kind and value then). Absent reads 0.
	drops: number?,
	noise: number?,
	woke: number?,
	dropKind: string?,
	dropValue: number?,
}

export type CrewLine = {
	userId: number,
	name: string,
	banked: number,
	piles: number,
	salvage: number,
	caught: number,
}

-- A joke award: its title (upper case, as stamped), who won it and the one-line reason ("hauled 140").
export type Award = {
	title: string,
	name: string,
	userId: number,
	detail: string,
}

-- The performance review (plain in M1-M2).
export type ShiftResults = {
	outcome: string,
	quota: number,
	cleared: number,
	bonus: number,
	-- Salvage items loaded, and piles vacuumed, by the whole crew.
	salvage: number,
	piles: number,
	-- Times Mr. Harlow caught someone this shift.
	catches: number,
	-- Salvage the shift's roll offered (open floor, under piles, in desks); `salvage` of `offered` were loaded.
	offered: number,
	rating: Rating,
	quotaMet: boolean,
	crew: { CrewLine },
	awards: { Award },
}

-- What every client sees (the `shift` world entry).
export type ShiftSnapshot = {
	phase: ShiftPhase,
	sub: ShiftSub,
	stage: ShiftStage,
	stageEndsAt: number?,
	tier: number,
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
	-- The crew's userIds (sorted), for the HUD's crew roster; empty in the lobby.
	crew: { number },
	-- The truck the crew came in (the depot's layout index), when the depart payload carried a valid one.
	truck: number?,
}

return {}
