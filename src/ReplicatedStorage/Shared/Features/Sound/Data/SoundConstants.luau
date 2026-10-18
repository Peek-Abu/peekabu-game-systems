--!strict
--[=[
	SoundConstants: the volume groups and their defaults. Static data (spec-exempt).

	@class SoundConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local groups: { SoundTypes.SoundGroupName } = { "Music", "SFX", "UI", "Ambient" }

local defaultVolumes: { [SoundTypes.SoundGroupName]: number } = {
	Music = 0.5,
	SFX = 1,
	UI = 0.8,
	Ambient = 0.7,
}

-- Annotated (and frozen in place, not through a frozen literal) so the group-name literal types survive;
-- an unannotated or freeze-wrapped literal widens them to `string`.
local SoundConstants: {
	GROUPS: { SoundTypes.SoundGroupName },
	DEFAULT_GROUP_VOLUMES: { [SoundTypes.SoundGroupName]: number },
	DEFAULT_SERVER_RADIUS: number,
	DEFAULT_FADE: number,
	IDLE_PER_PLACE: number,
	IDLE_SHARED: number,
	PREWARM_2D: number,
	PREWARM_POINTS: number,
	LOAD_TIMEOUT: number,
	DEFAULT_ROLL_OFF_MAX: number,
} =
	table.freeze({
		GROUPS = table.freeze(groups),
		DEFAULT_GROUP_VOLUMES = table.freeze(defaultVolumes),
		-- How far a server-requested positional sound reaches when the caller gives no radius.
		DEFAULT_SERVER_RADIUS = 150,
		-- Default crossfade for music and ambience, in seconds.
		DEFAULT_FADE = 1.5,
		-- One-shot voices kept idle for reuse per place they play from (a foot, a pile): a walk needs one a foot, a
		-- sprint's overlapping steps two (SoundServiceClient:playOneShot).
		IDLE_PER_PLACE = 3,
		-- ...and for the places many sounds share (2D in SoundService, the fixed points' anchors in the Terrain): a chase
		-- alone holds five stems, its sting, the heartbeat and the dread loop in 2D.
		IDLE_SHARED = 12,
		-- Idle voices made at client start in 2D and at the fixed-point anchors (SoundServiceClient:prewarm), so the
		-- shift's music stings, UI, sweeteners, pops and server-requested sounds never create a Sound mid-play.
		PREWARM_2D = 12,
		PREWARM_POINTS = 8,
		-- A sound still not loaded this long after its play (a failed or missing asset) is released: its Ended never
		-- fires, so it would otherwise hold its Sound and its concurrency slot for good.
		LOAD_TIMEOUT = 8,
		-- The engine's Sound.RollOffMaxDistance, restored on a reused voice whose sound gives none.
		DEFAULT_ROLL_OFF_MAX = 10000,
	})

return SoundConstants
