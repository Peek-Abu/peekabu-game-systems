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
} =
	table.freeze({
		GROUPS = table.freeze(groups),
		DEFAULT_GROUP_VOLUMES = table.freeze(defaultVolumes),
		-- How far a server-requested positional sound reaches when the caller gives no radius.
		DEFAULT_SERVER_RADIUS = 150,
		-- Default crossfade for music and ambience, in seconds.
		DEFAULT_FADE = 1.5,
	})

return SoundConstants
