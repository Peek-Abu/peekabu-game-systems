--!strict
--[=[
	AnimationLocomotionRegistry: the animation domain AnimationLocomotionSystem plays (Phase 6 spec, Decisions 1 + 3).

	Seeded 2026-07-20 from the ids the old game's RUNNING `Animate` fork actually played — its
	`Animation` config-children in `StarterCharacterScripts`, the live truth — NOT its stale internal
	tables or the `RS.Modules.Animate` copy. The native R15 idle was corrected on 2026-10-11 after a
	same-rig comparison, and the jump and fall on 2026-10-13 (see their entries); the remaining inherited
	clips are provisional until their feel/id sign-off.

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
	-- Stock R15 idle: the inherited Venture clip raised both arms on native engine avatars.
	idle = entry("rbxassetid://507766666", true),
	walk = entry("rbxassetid://11257118786", true),
	run = entry("rbxassetid://11525748624", true),
	-- Stock R15 jump and fall (2026-10-13). The inherited clips (jump 9126863232, fall 11525896362) were
	-- authored for the old game's custom controller: the jump opens on a ground crouch (hips 0.6-0.9 studs
	-- down, knees ~90 degrees) and the fall holds a deep tuck with the hips 0.89 down. A native Humanoid fires
	-- Jumping at takeoff, so the crouch played in the air and the tuck pushed the feet through the floor while
	-- it blended out on landing: the "legs bug out" on every rig.
	jump = entry("rbxassetid://507765000", false),
	fall = entry("rbxassetid://507767968", true),
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
