--!strict
--[=[
	LockerAssets: the Locker opening cutscene's sounds (owner pick 11-16: "Add sounds now from the Roblox library ...
	and make our own versions later"). Registers them at load (guarded); LockerCutsceneSystem plays them on its beats.

	⚠ NOT APPROVED, ALL OF THEM. Every id below is a Creator Store library pick made by an agent without a listening
	round, to be replaced (probably) by in-house versions (owner 11-16: "ENSURE WE MAKE NOTE OF WHAT SOUNDS WE TAKE! We
	already use library sounds that HAVE BEEN APPROVED! These are ones that haven't been / will be replaced"). Keep this
	list in sync with `docs/odd-hours-unapproved-sounds.md`; when a sound is approved or replaced, update both.

	| id | Creator Store asset | when it plays |
	|---|---|---|
	| lockerKey | Vice Grips 29 (SFX), ProSoundEffects, 9120409020 | the key turns in the lock |
	| lockerRattle | Security Gate 4 (SFX), ProSoundEffects, 9118901593 | the shut door rattles (louder the rarer) |
	| lockerChimeHigh | Roblox GUI - Notification High, Roblox, 17208361335 | the prize chime: Legendary only |
	| lockerChimeAura | Roblox GUI - Aura, Roblox, 17208327798 | the sparkle layer: Legendary only |

	(Notification High is also the approved tutorial pop; here it is a separate, unapproved use.)

	Owner 11-16 (heard in play): the key / lock sound is "alright"; the door-burst sound (Steel Door 3) and the Uncommon
	chime (Notification Low) were hated and are gone (the door now opens with lockerDoor, and Uncommon has its own
	in-house chime, below).

	APPROVED (owner sound tryout round 2, 2026-11-17): lockerDoor, the door swinging open as the burst starts. ElevenLabs
	SFX made on the Starter plan, owner pick C, Icey Labs 122487039015014 (a metal locker latch clicks, the thin door
	swings open and bangs gently on the next locker). Not a library pick, so not in the list above.

	APPROVED (owner rarity-ladder pick 2026-11-17): the prize chimes at the burst, one per rarity (LockerCutsceneViewModel
	RARITY_FX[*].chime): lockerCommon, lockerUncommon, lockerRare, lockerEpic and lockerOdd. In-house tuned orchestral
	stings (ElevenLabs Starter stems hand-layered with mix_sting.py; one family in F major growing from Common up, Odd a
	ghostly B minor), Icey Labs. Not library picks, so not in the list above. Each volume is a starting level that awaits
	the owner's hear-check (the louder-mastered files start lower so the ladder still rises). Legendary keeps the two
	library layers above for now: its grander sting is pending the owner's OK.

	Static data + registration (spec-exempt).

	@class LockerAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	lockerKey = { assetId = "rbxassetid://9120409020", group = "SFX", volume = 0.8, maxConcurrent = 1 },
	lockerRattle = { assetId = "rbxassetid://9118901593", group = "SFX", volume = 0.7, maxConcurrent = 1 },
	lockerDoor = { assetId = "rbxassetid://122487039015014", group = "SFX", volume = 0.8, maxConcurrent = 1 },
	-- Owner rarity-ladder pick 2026-11-17, in-house, Icey Labs (see the header). Played once at the burst by
	-- LockerCutsceneSystem; each volume is a starting level awaiting the owner's hear-check.
	-- Common: a tiny soft harp note, 0.85 s (-20 LUFS). Common had no chime before; the owner chose to add this.
	lockerCommon = {
		assetId = "rbxassetid://72279854240828",
		group = "SFX",
		bus = "Reward",
		volume = 0.7,
		maxConcurrent = 1,
	},
	-- Uncommon: two rising notes onto a soft chord with a long natural ring-out, 2.9 s (-18 LUFS). Plays to the end
	-- (owner: "ensure the sound is played to completion"): a 2D one-shot the cutscene's cleanup never stops.
	lockerUncommon = {
		assetId = "rbxassetid://129210679520094",
		group = "SFX",
		bus = "Reward",
		volume = 0.8,
		maxConcurrent = 1,
	},
	-- Rare: a small flourish into a warm chord, 1.73 s (-16 LUFS).
	lockerRare = {
		assetId = "rbxassetid://116606102485127",
		group = "SFX",
		bus = "Reward",
		volume = 0.9,
		maxConcurrent = 1,
	},
	-- Epic: a full-orchestra F major hit, 2.05 s (-13 LUFS; the same asset as UIAssets.shopBuyLegendary, under its own
	-- id here). Mastered loud, so it starts lower.
	lockerEpic = {
		assetId = "rbxassetid://125716350432533",
		group = "SFX",
		bus = "Reward",
		volume = 0.7,
		maxConcurrent = 1,
	},
	-- Odd: a ghostly B minor sting, 2.8 s (-13 LUFS). Mastered loud, so it starts lower.
	lockerOdd = {
		assetId = "rbxassetid://99943822258297",
		group = "SFX",
		bus = "Reward",
		volume = 0.7,
		maxConcurrent = 1,
	},
	-- Library picks, NOT approved: Legendary's chime and sparkle layers until its grander sting is approved.
	lockerChimeHigh = {
		assetId = "rbxassetid://17208361335",
		group = "SFX",
		bus = "Reward",
		volume = 1.6,
		maxConcurrent = 1,
	},
	lockerChimeAura = {
		assetId = "rbxassetid://17208327798",
		group = "SFX",
		bus = "Reward",
		volume = 1.4,
		maxConcurrent = 1,
	},
}

for id, def in SOUNDS do
	if not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	sounds = table.freeze(SOUNDS),
})
