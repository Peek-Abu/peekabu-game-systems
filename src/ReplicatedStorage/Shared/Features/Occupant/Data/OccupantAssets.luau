--!strict
--[=[
	OccupantAssets: every asset id Mr. Harlow uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"): his sounds, his grin image, his animation slots, and his body: the art-owned
	"A - Smile Mask" template in the place (characters/manager: a very tall porcelain-faced manager in a too-small
	suit, a long neck the head turns on, one SurfaceAppearance per painted face in its `Faces` folder). An id is PENDING ("") until the developer uploads the
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

-- The painted faces his template's `Faces` folder holds (OccupantFaceUtils picks one per mode).
export type Face = "Calm" | "Noticing" | "Hunting"

local PENDING = ""

-- His body: a Model under ReplicatedStorage (art-owned, never in the source tree; built by
-- characters/manager/assemble_manager.luau). Missing (a bare test place) = the generated fallback body.
local TEMPLATE_PATH: { string } = { "Assets", "CleanupCrew", "Characters", "Manager" }
local FACES: { Face } = { "Calm", "Noticing", "Hunting" }

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
	-- CC Manager Walk v1 / Run v1 (Icey Labs): a stiff, too-upright patrol walk planted at 10 studs/s and a
	-- long-striding chase run planted at 20 studs/s, keyed for the Smile Mask rig (characters/manager).
	harlowWalk = {
		assetId = "rbxassetid://81109952331244",
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		interruption = "ambient",
	},
	harlowRun = {
		assetId = "rbxassetid://81160103762255",
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		interruption = "ambient",
	},
	-- CC Manager Idle v1. His standing clip (investigating, searching, on break, over a catch): bolt upright, a slow doll tilt of the head.
	harlowLook = {
		assetId = "rbxassetid://77327530987223",
		looped = true,
		priority = Enum.AnimationPriority.Idle,
		interruption = "ambient",
	},
	-- CC Manager Sit Type v1: at a desk, stiffly typing with his long fingers (his pelvis on the seat through the Root
	-- joint; see SEAT for where the game puts him). The head turn layers over it.
	harlowSitType = {
		assetId = "rbxassetid://110578500987193",
		looped = true,
		priority = Enum.AnimationPriority.Idle,
		interruption = "ambient",
	},
	-- CC Manager Stand Up v1: from the seated pose (hands still) up to standing, ending SEAT.standOffset from the seat.
	harlowStandUp = {
		assetId = "rbxassetid://133807355222245",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		interruption = "protected",
	},
	-- CC Manager Head Turn v1: the head swivels 180 degrees on the long neck and back (keys only the Neck, so it
	-- layers over a walk). Registered for the game to play; nothing plays it yet.
	harlowHeadTurn = {
		assetId = "rbxassetid://127323899647722",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		interruption = "protected",
	},
	-- The catch: grab, then throw.
	harlowGrab = {
		assetId = PENDING,
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
	TEMPLATE_PATH = table.freeze(TEMPLATE_PATH),
	FACES = table.freeze(FACES),
	-- On the template: the face plate (welded to the Head), the SurfaceAppearance on it, the attribute naming the
	-- face it shows, and the folder of faces.
	FACE_PLATE = "FacePlate",
	FACE_APPEARANCE = "Face",
	FACE_ATTRIBUTE = "ManagerFace",
	FACES_FOLDER = "Faces",
	-- The studs/s his walk and run clips plant their feet at when played at 1x (the Npc base plays them at his speed
	-- / that, so his feet stay planted at every tier).
	PLANTED_SPEEDS = table.freeze({ harlowWalk = 10, harlowRun = 20 }),
	-- His clipboard: its own part on the template (Motor6D ClipboardGrip on the RightHand), hidden while he types.
	CLIPBOARD = "Clipboard",
	-- Sitting at an office desk (harlowSitType / harlowStandUp, measured against the built desk and chair): anchor his
	-- HumanoidRootPart at the chair's centre, at the height it has standing on that floor, facing the desk; the clips
	-- lower his pelvis onto the seat. harlowStandUp ends standing standOffset away (root space, -Z toward the desk):
	-- move the root there when it ends.
	SEAT = table.freeze({ standOffset = Vector3.new(0, 0, -1.1) }),
	SOUNDS = table.freeze(SOUNDS),
	GIBBERISH = table.freeze(GIBBERISH),
	IMAGES = table.freeze(IMAGES),
	ANIMATIONS = table.freeze(ANIMATIONS),
})
