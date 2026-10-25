--!strict
--[=[
	AnimationEmoteRegistry: the emote clips (Character step 5). One entry per emote item, keyed `emote:<item id>`
	(EmoteRules.clipKey), e.g. `emote:Pippa.Wave`. Every entry is a replicated action (the server grants it, everyone
	sees it): `replicable = true`, layer `full`, interruption `protected` (an attack never cuts an emote), priority
	Action, the next unused wireId (permanent), and `durationMs` measured in Studio for a one-shot.

	EMPTY until the owner supplies the clips: an emote with no entry shows "Coming soon" and never plays.

	@class AnimationEmoteRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

local AnimationEmoteRegistry: AnimationTypes.AnimationDomain = table.freeze({})

return AnimationEmoteRegistry
