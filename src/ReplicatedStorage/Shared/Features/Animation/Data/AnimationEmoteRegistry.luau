--!strict
--[=[
	AnimationEmoteRegistry: the emote clips (Character step 5). One entry per emote item, keyed `emote:<item id>`
	(EmoteRules.clipKey), e.g. `emote:Pippa.Wave`. Every entry is a replicated action (the server grants it, everyone
	sees it): `replicable = true`, layer `full`, interruption `protected` (an attack never cuts an emote), priority
	Action, the next unused wireId (permanent), and `durationMs` measured in Studio for a one-shot.

	An emote with no entry shows "Coming soon" and never plays. A clip that brings out props is also in
	EmotePropRegistry; its prop poses and PropsShow / PropsStow markers are in the clip
	(characters/skins/runtime-candidates-2026-10-26/legendary-clips-2026-10-29).

	@class AnimationEmoteRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

local function emote(assetId: string, wireId: number, durationMs: number): AnimationTypes.AnimationDef
	local def: AnimationTypes.AnimationDef = {
		assetId = assetId,
		priority = Enum.AnimationPriority.Action,
		looped = false,
		interruption = "protected",
		replicable = true,
		wireId = wireId,
		layer = "full",
		durationMs = durationMs,
	}
	return table.freeze(def)
end

local AnimationEmoteRegistry: AnimationTypes.AnimationDomain = table.freeze({
	-- Bubble Buddy's Bubble Ride (Legendary): 150 frames at 30 fps, wand out frames 4-146, held through her fist (one
	-- constant prop pose); markers drive the bubbles and faces (EmoteEffectRegistry). legendary-v2-2026-10-29/pippa_bubble_ride.
	["emote:Pippa.Bubbles"] = emote("rbxassetid://110605952847751", 4, 4967),
	-- Sheriff Prickles' Big Roundup (Legendary): 170 frames at 30 fps, coil out frames 12-162 (a loop 28-108), every
	-- frame clear of his head and hat; markers drive the dust, the tumbleweed and faces (EmoteEffectRegistry).
	-- legendary-v2-2026-10-29/prickles_big_roundup.
	["emote:Prickles.Lasso"] = emote("rbxassetid://110122539503132", 5, 5633),
	-- PJ Cappy's Cocoa Sip (Legendary): 121 frames at 30 fps, the pillow (left hand) and cocoa mug (right hand) out
	-- frames 8-113, posed every frame against the hand. legendary-clips-2026-10-29/cappy_prop_clips.py.
	["emote:Cappy.CocoaSip"] = emote("rbxassetid://83337271778720", 6, 4000),
})

return AnimationEmoteRegistry
