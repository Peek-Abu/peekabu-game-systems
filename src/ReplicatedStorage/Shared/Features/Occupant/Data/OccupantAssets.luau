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
	harlowCurious = { assetId = "rbxassetid://95530818541505", group = "SFX", volume = 0.8, rollOffMaxDistance = 90 },
	-- His typing while he sits at a desk (looped on his head, heard through rooms; the office typist's clip, reused). It
	-- stops dead in the ambush.
	harlowTyping = {
		assetId = "rbxassetid://71155319819913",
		group = "SFX",
		volume = 0.65,
		looped = true,
		rollOffMaxDistance = 70,
	},
	-- The near warning stage: a low dread swell under everything while he is close and not chasing you (looped, 2D;
	-- its volume follows how close he is). PLACEHOLDER slot: pending.
	harlowDread = { assetId = PENDING, group = "Ambient", volume = 0.5, looped = true },
	-- The ambush: he snaps round from the desk, chair shove, porcelain grind and the lock of his head over a pizz F dim7
	-- (round-2 pick A, in-house, 1.1 s = AMBUSH_HOLD; positional). Plays as the ambush starts.
	harlowAmbush = { assetId = "rbxassetid://90232187116807", group = "SFX", volume = 0.9, rollOffMaxDistance = 60 },
	-- He sits at a desk: casters roll the chair in, the seat creaks, the gas lift sighs and bottoms out (round-3 pick A,
	-- in-house; positional, heard through the room). Plays as he reaches the chair.
	harlowSit = { assetId = "rbxassetid://118633870993827", group = "SFX", volume = 0.9, rollOffMaxDistance = 70 },
	-- His chair swivels as he rises out of the ambush (round-2 pick A = round-1 C + D layered): our SA3 squeak and
	-- ceramic creak, played with the two library layers of that mix by their own ids (the user approved, 2026-10-17):
	-- PSE "Office Chair 1" and APM "BASSBEND-Down 05". Their volumes are the mix's gains (-4.6 / -17.6 dB against
	-- ours); SWIVEL says where each starts and stops.
	deskSwivel = { assetId = "rbxassetid://80676054119585", group = "SFX", volume = 0.9, rollOffMaxDistance = 60 },
	deskSwivelChair = { assetId = "rbxassetid://9117143754", group = "SFX", volume = 0.53, rollOffMaxDistance = 60 },
	deskSwivelBend = { assetId = "rbxassetid://9043357191", group = "SFX", volume = 0.12, rollOffMaxDistance = 60 },
	-- The "spotted" sting at every chase start (2D for the one he chases, positional for everyone else).
	harlowSpotted = { assetId = "rbxassetid://71081947321557", group = "SFX", volume = 1, rollOffMaxDistance = 90 },
	-- The chase music for the chased player (round-2 pick B "Clockwork mallets", in-house: B minor, 144 bpm, 16 bars =
	-- 26.67 s, bar-exact OGG loops; 2D, for as long as the chase on you lasts, under your racing heartbeat). One sting
	-- bar, then five stems from one score with one common gain, so they sum to the mix (OccupantChaseMusicSystem):
	-- intensity 1 = ostinato + low, intensity 2 adds motif, ticks and pulse as he closes (CHASE_STEMS).
	harlowChaseSting = { assetId = "rbxassetid://136144780062166", group = "SFX", volume = 0.9 },
	harlowChase_ostinato = { assetId = "rbxassetid://76713573491371", group = "Music", volume = 0.9, looped = true },
	harlowChase_low = { assetId = "rbxassetid://87740742060998", group = "Music", volume = 0.9, looped = true },
	harlowChase_motif = { assetId = "rbxassetid://94072671705529", group = "Music", volume = 0.9, looped = true },
	harlowChase_ticks = { assetId = "rbxassetid://112793987544288", group = "Music", volume = 0.9, looped = true },
	harlowChase_pulse = { assetId = "rbxassetid://112510222070935", group = "Music", volume = 0.9, looped = true },
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
	-- You respawn after a catch, with the Rehired card: the time clock punches you back IN + glock C-F up a fourth
	-- (round-3 pick A; 2D, only for you).
	catchRehired = { assetId = "rbxassetid://80163458987401", group = "SFX", volume = 0.9 },
	-- He throws you: FIRED (round-3 final pick F1 "heavy stamp": a backwards piano F dim7 swell into a heavy rubber
	-- stamp on metal; 2D, only for the caught player; it replaces the engine's "oof"). Its stamp lands FIRED_HIT
	-- seconds into the file, so it starts that long before the throw (OccupantScareSystem.snap).
	catchFired = { assetId = "rbxassetid://99003711272251", group = "SFX", volume = 1 },
}

-- The chase music's stems (OccupantChaseMusicSystem): `base` plays the whole chase, `near` fades in as he closes. The
-- first base stem is the one the others stay locked to.
local CHASE_STEMS: { base: { string }, near: { string } } = {
	base = { "harlowChase_ostinato", "harlowChase_low" },
	near = { "harlowChase_motif", "harlowChase_ticks", "harlowChase_pulse" },
}

-- The desk swivel's library layers, as the round-2 mix placed them: the PSE chair starts `start` seconds into its file
-- (its lead-in, trimmed in the mix) and each stops `stopAt` seconds in, fading `fade` seconds (the mix's cut).
export type SwivelLayer = { id: string, start: number, stopAt: number, fade: number }
local SWIVEL: { SwivelLayer } = {
	{ id = "deskSwivelChair", start = 0.14, stopAt = 0.85, fade = 0.15 },
	{ id = "deskSwivelBend", start = 0.03, stopAt = 0.8, fade = 0.4 },
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
	-- joint; see SEAT for where the game puts him). OccupantSeatSystem plays it at Action priority (over the base NPC's
	-- idle pose) and the stand-up at Action2; the gestures (OccupantGestureSystem) layer over both.
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
	-- layers over a walk). Registered; the ambush's swivel is procedural instead (OccupantGestureFormulas "swivel",
	-- aimed at the point).
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
	CHASE_STEMS = table.freeze({ base = table.freeze(CHASE_STEMS.base), near = table.freeze(CHASE_STEMS.near) }),
	SWIVEL = table.freeze(SWIVEL),
	-- Where catchFired's stamp hits, in seconds from its start (fired_F1.mix.json hit_at_s).
	FIRED_HIT = 0.322,
	GIBBERISH = table.freeze(GIBBERISH),
	IMAGES = table.freeze(IMAGES),
	ANIMATIONS = table.freeze(ANIMATIONS),
})
