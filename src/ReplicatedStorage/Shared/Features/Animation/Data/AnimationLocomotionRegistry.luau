--!strict
--[=[
	AnimationLocomotionRegistry: the animation domain AnimationLocomotionSystem plays (Phase 6 spec, Decisions 1 + 3).

	Seeded 2026-07-20 from the ids the old game's RUNNING `Animate` fork actually played — its
	`Animation` config-children in `StarterCharacterScripts`, the live truth — NOT its stale internal
	tables or the `RS.Modules.Animate` copy. Every id here is provisional until the developer's V5
	feel/id sign-off checkpoint; replacing one is a one-line edit.

	Census oddities deliberately NOT carried over (flagged for V5): the fork's `walk` set contained a
	second id that is the STOCK CHEER emote, and `toolslash`/`toollunge` both pointed at the death
	animation — evidence of drift, not intent.

	Two groups:
	- CORE poses — what AnimationLocomotionSystem animates this phase (contract tested in the spec).
	- Movement-phase seeds — captured now because the fork carried them (sneak/slow-walk/sprint set);
	  unused until the Movement phase adds their poses through the pose API.

	All entries are `ambient`: a bulk combat stop must never kill locomotion.

	@class AnimationLocomotionRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

type AnimationDomain = AnimationTypes.AnimationDomain

local function entry(assetId: string, looped: boolean, variants: { string }?): AnimationTypes.AnimationDef
	local def: AnimationTypes.AnimationDef = {
		assetId = assetId,
		-- Core is what the engine's own Animate uses for locomotion: everything gameplay plays
		-- (Idle/Movement/Action*) naturally sits above it without per-consumer priority fiddling.
		priority = Enum.AnimationPriority.Core,
		looped = looped,
		interruption = "ambient",
		variants = if variants ~= nil then table.freeze(variants) else nil,
	}
	return table.freeze(def)
end

local AnimationLocomotionRegistry: AnimationDomain = table.freeze({
	-- CORE poses (the AnimationLocomotionSystem contract).
	idle = entry("rbxassetid://11526063910", true),
	walk = entry("rbxassetid://11257118786", true),
	run = entry("rbxassetid://11525748624", true),
	jump = entry("rbxassetid://9126863232", false),
	fall = entry("rbxassetid://11525896362", true),
	climb = entry("rbxassetid://507765644", true),
	swim = entry("rbxassetid://913384386", true),
	swimidle = entry("rbxassetid://913389285", true),
	sit = entry("rbxassetid://2506281703", true),
	-- No death entry ON PURPOSE (V5 decision): the old game deprecated its death animation. On
	-- death, locomotion just stops and latches; what death LOOKS like belongs to the future
	-- Death/Ragdoll phase, in its own domain.

	-- Movement-phase seeds — carried from the fork, unused until Movement adds their poses.
	jumpland = entry("rbxassetid://11525764926", false),
	sprintjump = entry("rbxassetid://11525667271", false, { "rbxassetid://128472778455853" }),
	sprintturnleft = entry("rbxassetid://137597624157257", false),
	sprintturnright = entry("rbxassetid://81393384686501", false),
	sneakidle = entry("rbxassetid://11868152140", true),
	sneakwalk = entry("rbxassetid://11868165270", true),
	slowwalk = entry("rbxassetid://11245709896", true),
})

return AnimationLocomotionRegistry
