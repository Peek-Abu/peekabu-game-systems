--!strict
--[=[
	RankTypes: the company rank's shapes (Cleanup Crew "Clearance Level"). Types only.

	@class RankTypes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

-- The stored rank (the `rank` profile slice, or the session copy when RankConstants.RANK_PERSIST is false).
export type RankState = PlayerDataTypes.Rank

-- One rung of the ladder (RankRegistry). Cosmetic only: a level never changes what a player can do.
export type Level = {
	level: number,
	name: string,
	-- Total XP that reaches this level.
	xp: number,
	-- The lanyard colour this level wears (data only until a lanyard asset exists; the name tag shows a strip).
	lanyard: Color3,
	lanyardName: string,
}

-- Where an XP total sits on the ladder.
export type Progress = {
	level: Level,
	-- Absent at the top of the ladder.
	next: Level?,
	xp: number,
	-- XP earned inside the current level, and the XP between this level and the next (0 at the top).
	into: number,
	span: number,
	-- 0..1 of the way to the next level; 1 at the top.
	fill: number,
}

-- One crew member's run as the XP rules read it: the server maps it from Shift's roster (ShiftReviewSystem.crew), the
-- results card from the published review's crew lines.
export type CrewEntry = {
	userId: number,
	caught: number,
	items: number,
	overtimeSalvage: number,
}

-- What one player did in one shift, as the XP rules read it (RankFormulas.factsFor builds it from the crew).
export type ShiftFacts = {
	-- On the shift's review (the crew that took part).
	worked: boolean,
	quotaMet: boolean,
	-- Cargo items this player banked, and salvage items they banked during overtime.
	items: number,
	overtimeSalvage: number,
	-- Still with the crew at the end and never caught.
	extracted: boolean,
	-- Caught by the Manager at least once (no extraction bonus; an incident report line instead).
	caught: boolean,
	-- Every crew member on the review extracted.
	crewExtracted: boolean,
}

export type AwardKey = "shiftWorked" | "quotaMet" | "items" | "overtimeSalvage" | "extracted" | "crewExtracted"

export type AwardLine = {
	key: AwardKey,
	label: string,
	xp: number,
}

-- One shift's pay-out: the lines in display order, their total, and whether an incident report was filed.
export type Award = {
	total: number,
	lines: { AwardLine },
	incident: boolean,
}

return {}
