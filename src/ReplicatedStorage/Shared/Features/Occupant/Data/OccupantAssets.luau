--!strict
--[=[
	OccupantAssets: every asset id Mr. Harlow uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"): his sounds, his grin image, and his animation slots ("lurch walk,
	look-around, grab and throw", from Kimodo/MoMask). An id is PENDING ("") until the developer uploads the
	staged file (the M3 plan's "Asset staging" appendix). A pending sound is never registered (silent); a pending
	grin falls back to a grin built from frames (OccupantScareSystem); a pending animation is left out of the
	`occupant` animation domain, so he keeps the base clips (OccupantAnimationUtils). Registers the uploaded sounds
	at load on whichever realm requires this first (guarded).

	Static data + registration (spec-exempt).

	@class OccupantAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

export type AnimationSlot = {
	assetId: string,
	looped: boolean,
	priority: Enum.AnimationPriority,
	interruption: AnimationTypes.InterruptionClass,
}

local PENDING = ""

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- His heavy, uneven step (one per stride, positional, through walls).
	harlowFootstep = {
		assetId = "rbxassetid://119846856442242",
		group = "SFX",
		volume = 0.7,
		pitch = { min = 0.9, max = 1.05 },
		rollOffMaxDistance = 70,
		maxConcurrent = 2,
	},
	-- His tell: a pen tapping on his clipboard (looped on his head, heard through walls).
	harlowMutter = {
		assetId = "rbxassetid://135690215756036",
		group = "SFX",
		volume = 0.35,
		looped = true,
		rollOffMaxDistance = 55,
	},
	-- Your heartbeat while he is near and has not seen you (2D).
	harlowHeartbeat = { assetId = "rbxassetid://123214528916758", group = "SFX", volume = 0.8 },
	-- He heard something: one deliberate pen click (the tapping cue for "?").
	harlowCurious = { assetId = "rbxassetid://95530818541505", group = "SFX", volume = 0.8, rollOffMaxDistance = 80 },
	-- The "!" sting (2D for the one he spotted, positional for everyone else).
	harlowSpotted = { assetId = "rbxassetid://71081947321557", group = "SFX", volume = 1, rollOffMaxDistance = 90 },
	-- Chase music for the chased player (looped).
	harlowChase = { assetId = PENDING, group = "Music", volume = 0.6, looped = true },
	harlowSigh = { assetId = "rbxassetid://126145488520317", group = "SFX", volume = 0.8, rollOffMaxDistance = 80 },
	-- His 'voice': him scribbling you up on his clipboard, one clip per line (OccupantFeedbackUtils.clipFor picks among
	-- the uploaded ones, so one clip covers every line until more are added).
	harlowGibberish1 = {
		assetId = "rbxassetid://112161993953770",
		group = "SFX",
		volume = 0.9,
		pitch = { min = 0.92, max = 1.12 },
		rollOffMaxDistance = 90,
	},
	harlowGibberish2 = {
		assetId = PENDING,
		group = "SFX",
		volume = 0.9,
		pitch = { min = 0.92, max = 1.12 },
		rollOffMaxDistance = 90,
	},
	harlowGibberish3 = {
		assetId = PENDING,
		group = "SFX",
		volume = 0.9,
		pitch = { min = 0.92, max = 1.12 },
		rollOffMaxDistance = 90,
	},
	harlowGibberish4 = {
		assetId = PENDING,
		group = "SFX",
		volume = 0.9,
		pitch = { min = 0.92, max = 1.12 },
		rollOffMaxDistance = 90,
	},
	-- The catch: a distorted sting for the caught player, the lights' power-down and his grab for everyone near.
	harlowCatchSting = { assetId = "rbxassetid://88133727845312", group = "SFX", volume = 1 },
	harlowPowerDown = { assetId = "rbxassetid://95527531363916", group = "SFX", volume = 0.9, rollOffMaxDistance = 90 },
	harlowGrab = { assetId = "rbxassetid://9113482942", group = "SFX", volume = 0.9, rollOffMaxDistance = 60 },
}

local GIBBERISH: { string } = { "harlowGibberish1", "harlowGibberish2", "harlowGibberish3", "harlowGibberish4" }

-- The stretched grin shown over his face for the catch (Flux; transparent PNG).
local IMAGES: { grin: string } = {
	grin = PENDING,
}

local ANIMATIONS: { [string]: AnimationSlot } = {
	-- Lurch walk (patrol), and a run if one is made (else the base run).
	harlowWalk = {
		assetId = PENDING,
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		interruption = "ambient",
	},
	harlowRun = {
		assetId = PENDING,
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		interruption = "ambient",
	},
	-- Look-around: his standing clip (investigating, searching, on break, over a catch).
	harlowLook = { assetId = PENDING, looped = true, priority = Enum.AnimationPriority.Idle, interruption = "ambient" },
	-- The catch: grab, then throw.
	harlowGrab = {
		assetId = "rbxassetid://9113482942",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		interruption = "protected",
	},
	harlowThrow = {
		assetId = PENDING,
		looped = false,
		priority = Enum.AnimationPriority.Action,
		interruption = "protected",
	},
}

for id, def in SOUNDS do
	if def.assetId ~= PENDING and not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	PENDING = PENDING,
	SOUNDS = table.freeze(SOUNDS),
	GIBBERISH = table.freeze(GIBBERISH),
	IMAGES = table.freeze(IMAGES),
	ANIMATIONS = table.freeze(ANIMATIONS),
})
