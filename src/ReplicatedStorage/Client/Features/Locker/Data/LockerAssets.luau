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
	| lockerChimeHigh | Roblox GUI - Notification High, Roblox, 17208361335 | the prize chime: Rare, Epic, Legendary |
	| lockerChimeAura | Roblox GUI - Aura, Roblox, 17208327798 | the sparkle layer: Epic and Legendary only |

	(Notification High is also the approved tutorial pop; here it is a separate, unapproved use.)

	Owner 11-16 (heard in play): the key / lock sound is "alright"; the door-burst sound (Steel Door 3) and the Uncommon
	chime (Notification Low) were hated and are gone: the door opens silent and Uncommon has no chime.

	APPROVED (owner sound tryout round 2, 2026-11-17): lockerDoor, the door swinging open as the burst starts. ElevenLabs
	SFX made on the Starter plan, owner pick C, Icey Labs 122487039015014 (a metal locker latch clicks, the thin door
	swings open and bangs gently on the next locker). Not a library pick, so not in the list above.

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
