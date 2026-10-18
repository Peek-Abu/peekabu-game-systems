--!strict
--[=[
	ShiftStoryFixtures: static sample data for the Shift stories (UI Labs): a running shift for crew Sam, Alex and Jo
	in truck 2, their public entries (Sam carrying a coffee machine, Alex caught and back in 6 s, Jo vacuuming) and the local
	player's entry (a monitor in both hands from hotbar slot 4, a plaque and an appraised coffee mug pocketed, the canister gauge on the contract's Gloom). Story time is 0. No logic.

	@class ShiftStoryFixtures
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

-- What a story changes on the sample shift; anything left nil keeps the sample's value.
export type SnapshotChanges = {
	endsAt: number?,
	cleared: number?,
	quotaMet: boolean?,
	stage: ShiftTypes.ShiftStage?,
	tier: number?,
	sub: ShiftTypes.ShiftSub?,
	clockOutAt: number?,
	-- Who has clocked out and how many crew members are still in (default: nobody of 3).
	punched: { number }?,
	crewIn: number?,
}

local NAMES: { [number]: string } = { [1] = "Sam", [2] = "Alex", [3] = "Jo" }

local PLAYERS: PublicPlayerTypes.PublicPlayerMap = {
	["1"] = { carrying = "coffeeMachine", inTruck = true },
	["2"] = { caughtUntil = 6, dead = true },
	["3"] = { vacuuming = true, room = "Archive" },
}

local ME: PublicPlayerTypes.PublicPlayer = {
	carrying = "monitor",
	inv1 = "plaque",
	inv2 = "coffeeMug",
	inv2Value = 34,
	inv3 = "monitor",
	invHands = 3,
}

local ShiftStoryFixtures = {
	names = NAMES,
	players = PLAYERS,
	me = ME,
}

-- A running shift, 4:12 left at story time 0, with `changes` applied.
function ShiftStoryFixtures.snapshot(changes: SnapshotChanges): ShiftTypes.ShiftSnapshot
	return {
		phase = "running",
		sub = changes.sub or "normal",
		stage = changes.stage or "normal",
		tier = changes.tier or 1,
		shift = 1,
		endsAt = changes.endsAt or 252,
		clockOutAt = changes.clockOutAt,
		quota = 350,
		cleared = changes.cleared or 120,
		bonus = 40,
		quotaMet = changes.quotaMet == true,
		variant = "B",
		votesAnother = 0,
		votesDepot = 0,
		crew = { 1, 2, 3 },
		truck = 2,
		punched = changes.punched or {},
		crewIn = changes.crewIn or 3,
	}
end

return ShiftStoryFixtures
