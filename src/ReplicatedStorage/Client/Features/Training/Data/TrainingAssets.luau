--!strict
--[=[
	TrainingAssets: the sounds of Mr. Harlow's scripted pass at the training's escape stop (TrainingHallSystem). Client-only.
	Registers them at load (guarded).

	The STAFF door's creak as it swings open and his exit door's slam (3D, at the door; in-house, Icey Labs), and the
	relief sting when he has gone (2D). Also the finish fanfare and the guide's coach card (owner-picked; the guide is
	Prickles, TrainingConstants.GUIDE_EMPLOYEE).

	Static data + registration (spec-exempt).

	@class TrainingAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- An old wooden door creaking open: latch click, rusty hinge squeal over a low wood groan (2.0 s, -18 LUFS). In-house
	-- (ElevenLabs Starter stems hand-layered, Icey Labs), replacing the other-player upload "Door creak" (owner asset
	-- check fix 2, 11-18: a player's own upload can go private). Volume awaits the owner's hear-check.
	trainingDoorCreak = {
		assetId = "rbxassetid://101893971281061",
		group = "SFX",
		bus = "Action",
		volume = 1,
		rollOffMaxDistance = 80,
	},
	-- The door slammed shut: the bang, the latch snapping, a low boom and the door's glass rattling after (1.0 s, -16 LUFS).
	-- In-house (Icey Labs), replacing the other-player upload "Door Slam" (asset check fix 2, 11-18). Volume awaits the
	-- hear-check.
	trainingDoorSlam = {
		assetId = "rbxassetid://99736789284027",
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
	-- The guide's coach card (TrainingCoach: Prickles, or the step's own `coach`) showing a new line, once per new line
	-- (TrainingGuideRules.lineChanged), everywhere that card speaks (owner 11-17: "All dialogue events that leverage
	-- that same mechanic"):
	--   - a training run's stop and catch lines (TrainingServiceClient.onCoachLine, the TrainingGuideHud card);
	--   - every spotlight tour step's card as it first shows (TrainingSpotlightSystem.draw): the hub's "New here? Start
	--     training!" hint, the after-training Shop / trucks tour, "Play training again", a training run's first-stop
	--     tips and a first real shift's hotbar tour. The same line coming back (after a hold, a page closing, or the
	--     hub hint after stepping off the pad) does not play it again.
	-- A paper note slides onto a desk + a tiny desk bell (1.0 s, -20 LUFS). Owner tryout round 3 pick (2026-11-17);
	-- ElevenLabs SFX, Starter plan, Icey Labs. No sound played at any of these before. Volume 1 is a starting level
	-- that awaits the owner's hear-check.
	trainingCoachCard = { assetId = "rbxassetid://119489026512972", group = "UI", volume = 1, maxConcurrent = 1 },
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
	COACH_CARD = "trainingCoachCard",
	-- The coach's wave at the hub's Training pad (TrainingCoachSystem): wave v2, forearm-led from a bent elbow
	-- (owner 11-11), generic for every employee (design/animations/coach, Icey Labs, uploaded with the owner's OK
	-- 2026-11-11).
	COACH_WAVE = "rbxassetid://109921006694112",
})
