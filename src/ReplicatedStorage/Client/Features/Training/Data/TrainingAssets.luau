--!strict
--[=[
	TrainingAssets: the sounds of Mr. Harlow's scripted pass at the training's escape stop (TrainingHallSystem). Client-only.
	Registers them at load (guarded).

	INTERIM Creator Store picks (2026-11-10, free library audio, not yet heard by the owner): to be replaced by in-house
	sounds (game-sound-design) once he has listened. The STAFF door's creak as it swings open and his exit door's slam
	(3D, at the door), and the relief sting when he has gone (2D).

	Static data + registration (spec-exempt).

	@class TrainingAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- "Door creak" (Creator Store 96876231304223).
	trainingDoorCreak = {
		assetId = "rbxassetid://96876231304223",
		group = "SFX",
		bus = "Action",
		volume = 2.2,
		rollOffMaxDistance = 80,
	},
	-- "Door Slam" (Creator Store 121982576409852).
	trainingDoorSlam = {
		assetId = "rbxassetid://121982576409852",
		group = "SFX",
		bus = "Stings",
		volume = 0.9,
		rollOffMaxDistance = 90,
	},
	-- "Essential (sting)", APM Music on the Creator Store (9042046037): a warm, calm sting with a piano finish.
	trainingRelief = { assetId = "rbxassetid://9042046037", group = "SFX", bus = "Stings", volume = 0.7 },
	-- The "you finished training" screen: "Cartoon Fanfare (C)", APM Music on the Creator Store (1840120056), the owner's
	-- library-round pick B (2026-11-14), played in place. Its file opens on ~0.5 s of silence (no start offset exists),
	-- so the fanfare lands just after the screen. About -18 dB, a reward sting.
	trainingFinish = { assetId = "rbxassetid://1840120056", group = "SFX", bus = "Reward", volume = 2.7 },
}

for id, def in SOUNDS do
	if not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	SOUNDS = table.freeze(SOUNDS),
	CREAK = "trainingDoorCreak",
	SLAM = "trainingDoorSlam",
	RELIEF = "trainingRelief",
	FINISH = "trainingFinish",
	-- The coach's wave at the hub's Training pad (TrainingCoachSystem): wave v2, forearm-led from a bent elbow
	-- (owner 11-11), generic for every employee (design/animations/coach, Icey Labs, uploaded with the owner's OK
	-- 2026-11-11).
	COACH_WAVE = "rbxassetid://109921006694112",
})
