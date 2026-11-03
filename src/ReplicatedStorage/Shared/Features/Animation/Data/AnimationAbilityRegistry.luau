--!strict
--[=[
	AnimationAbilityRegistry: the employee ability clips (AbilityRegistry names them by key). Every entry is a
	replicated action the server grants over the effect (AbilityServiceServer: the effect never waits for a clip):
	`replicable = true`, interruption `protected`, priority Action, a permanent wireId from the 100s block (kept apart
	from the emote block), and `durationMs` for a one-shot. A full-body clip plays standing still; its `upper`
	twin (pelvis and legs at zero weight) plays on the upper layer while moving, so locomotion stays.

	Sources (owner-approved 2026-10-29): characters/launch/animation-workbench/workflow/launch-finish-2026-10-25/
	pippa/ability (Let's Go!, 3.0 s) and prickles/{enter,hold,exit} (Potted Plant; the hold loops). An ability whose
	clip is still to come has no entry here and plays nothing.

	@class AnimationAbilityRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

local function action(
	assetId: string,
	wireId: number,
	layer: AnimationTypes.AnimationLayer,
	durationMs: number?
): AnimationTypes.AnimationDef
	local def: AnimationTypes.AnimationDef = {
		assetId = assetId,
		priority = Enum.AnimationPriority.Action,
		looped = durationMs == nil,
		interruption = "protected",
		replicable = true,
		wireId = wireId,
		layer = layer,
		durationMs = durationMs,
	}
	return table.freeze(def)
end

local AnimationAbilityRegistry: AnimationTypes.AnimationDomain = table.freeze({
	-- Pippa's Let's Go! rally: gather, forward rally, fist pump, release (91 frames at 30 fps).
	pippaletsgo = action("rbxassetid://95260008210292", 100, "full", 3000),
	pippaletsgoupper = action("rbxassetid://135560107489055", 101, "upper", 3000),
	-- Cappy's Spot It! (v2, 111 frames at 30 fps): his phone out (PropsShow f12 to PropsStow f95, the hire reveal's
	-- grip) and his faces on Face markers (EmotePropRegistry, EmoteEffectRegistry).
	cappyspotit = action("rbxassetid://100572869358825", 102, "full", 3667),
	cappyspotitupper = action("rbxassetid://113713666510157", 103, "upper", 3667),
	-- Prickles' Potted Plant: into the pot (PropsShow f9), the still hold (looped, as long as the plant lasts) and the
	-- calm way out (PropsStow f41); his faces on Face markers (49 / 61 / 49 frames at 30 fps).
	pricklesplantenter = action("rbxassetid://110086044126223", 104, "full", 1600),
	pricklesplanthold = action("rbxassetid://80615841797051", 105, "full", nil),
	pricklesplantexit = action("rbxassetid://85927480911212", 106, "full", 1600),
})

return AnimationAbilityRegistry
