--!strict
--[=[
	OccupantRunTracker: what is true now about the running monster (split out of OccupantServiceServer). One live
	record, `run`, that OccupantServiceServer (his life: spawn, despawn, the shift, the developer seams) and
	OccupantBrainSystem (his thinks, catches and noises) both read and write: the rig and its kind, the brain's mind,
	the door beat, his last walk target, the shift, the office's layout for him, the noise he heard, the random rolls,
	the QA seams and the counters.

	@class OccupantRunTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local OccupantServer = ServerScriptService.Features.Occupant
local OccupantKindRegistry = require(OccupantShared.Data.OccupantKindRegistry)
local OccupantTypes = require(OccupantShared.Data.OccupantTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local Sense = require(OccupantServer.Systems.OccupantSenseSystem)
local OccupantRigSystem = require(OccupantServer.Systems.OccupantRigSystem)

-- (watchThinks / watchJerks: the per-frame watch during a slow turn, behaviours design §11.4.)
export type Counters = {
	spawned: number,
	heard: number,
	chases: number,
	catches: number,
	watchThinks: number,
	watchJerks: number,
}

export type Run = {
	rig: OccupantRigSystem.Rig?,
	-- The running rig's kind (the shift's roster pick; Harlow until one is built).
	currentKind: OccupantKindRegistry.KindId,
	mind: OccupantTypes.Mind?,
	-- Until when the door beat holds his walk (os.clock); reset with the mind.
	holdUntil: number,
	-- His last walk target (a goTo intent's position): his heading for the door beat while he stands still.
	lastGoal: Vector3?,
	shift: ShiftTypes.ShiftState?,
	-- The office's layout for him this shift (OccupantSenseSystem.layout; nil before he clocks in).
	place: Sense.World?,
	pendingNoise: Vector3?,
	rng: Random,
	-- A QA seam (`_setRolls`): fixed rolls for the brain instead of random ones (nil = random).
	fixedRolls: { number }?,
	-- A developer's forced head-turn variant (`occupantturn`), applied on the next think: which, and for whom.
	pendingForce: { kind: OccupantTypes.TurnKind | "auto", userId: number }?,
	counters: Counters,
}

local OccupantRunTracker = {}

-- A run with no monster yet.
function OccupantRunTracker.new(): Run
	return {
		rig = nil,
		currentKind = OccupantKindRegistry.DEFAULT,
		mind = nil,
		holdUntil = 0,
		lastGoal = nil,
		shift = nil,
		place = nil,
		pendingNoise = nil,
		rng = Random.new(),
		fixedRolls = nil,
		pendingForce = nil,
		counters = { spawned = 0, heard = 0, chases = 0, catches = 0, watchThinks = 0, watchJerks = 0 },
	}
end

-- The one live run.
OccupantRunTracker.run = OccupantRunTracker.new()

return OccupantRunTracker
