--!strict
--[=[
	OfficeAssets: every asset id the Office feature uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"): the office bed (four looped beds and the sweetener one-shots code scatters round
	you, pinned Building), the yard bed (its own four beds and sweeteners, pinned Outside, and the yard's fixed
	emitters' loops: yard design Y1, docs/superpowers/specs/2026-11-04-yard-place-design.md), a broken light's zap, the ambient dread (a phone ringing, the elevator's ding, typing), and the exterior
	anomalies' sounds (a cooling engine's tick, TV static, an automatic door). Client-only: nothing on the server
	plays them. An id is PENDING ("")
	until the developer uploads the staged file (the M3 plan's "Asset staging" appendix); a pending sound is never
	registered, so playing it is silent. Registers the uploaded sounds at load (guarded).

	Static data + registration (spec-exempt).

	@class OfficeAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local PENDING = ""

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- The office bed (round-2 pick A "night-shift hum", in-house, B minor): four looped beds of co-prime lengths
	-- (17.33 / 23.99 / 31.09 / 37.97 s), each moving on its own, mixed together to -21 LUFS; 2D under everything while
	-- the crew is in a shift (OfficeAtmosphereSystem). A synth hum on the tonic, the real fluorescent tube pitched to
	-- the 5th, HVAC air, and a minor-3rd cello colour that comes and goes. Pinned Building: silent in the yard.
	officeBedHum = {
		assetId = "rbxassetid://78387618185725",
		group = "Ambient",
		volume = 1,
		looped = true,
		place = "Building",
	},
	officeBedTube = {
		assetId = "rbxassetid://119618262674325",
		group = "Ambient",
		volume = 1,
		looped = true,
		place = "Building",
	},
	officeBedAir = {
		assetId = "rbxassetid://75154883738037",
		group = "Ambient",
		volume = 1,
		looped = true,
		place = "Building",
	},
	officeBedColour = {
		assetId = "rbxassetid://88550740744264",
		group = "Ambient",
		volume = 1,
		looped = true,
		place = "Building",
	},
	-- The yard bed (yard design Y1, in-house, the owner's pick B, 2026-11-04): the quiet, slightly lonely half of the
	-- night. Looped beds of co-prime lengths (17.33 / 31.09 / 37.97 s), 2D because they come from everywhere: a far
	-- sodium hum on B (the office's tonic, so the doors stay in one key), darker wind in the pines, and sparse crickets.
	-- Pinned Outside: silent in the building. (Its fourth layer, the far road, plays from the road side: yardTraffic.)
	yardBedLamp = {
		assetId = "rbxassetid://75472286543334",
		group = "Ambient",
		volume = 1,
		looped = true,
		place = "Outside",
	},
	yardBedWind = {
		assetId = "rbxassetid://110525679324475",
		group = "Ambient",
		volume = 1,
		looped = true,
		place = "Outside",
	},
	yardBedCrickets = {
		assetId = "rbxassetid://139015816808505",
		group = "Ambient",
		volume = 1,
		looped = true,
		place = "Outside",
	},
	-- The yard's fixed emitters (looped, 3D from the nearest point of their tagged part, pinned Outside so a source
	-- past the yard's boxes still plays there): a sodium pole's buzz at its lamp (pick A), the vending machine's hum
	-- (round-2 pick A2), the gate booth's tiny radio playing the hub's record, faint and a little warped ("a record left
	-- playing after closing": pick B, the harmony and hook, -55 cents), and the far road's wash from the road side
	-- (the bed's traffic layer, pick B). Full volume within rollOffMinDistance, gone at rollOffMaxDistance.
	yardLampBuzz = {
		assetId = "rbxassetid://78296703052028",
		group = "Ambient",
		volume = 0.5,
		looped = true,
		rollOffMinDistance = 3,
		rollOffMaxDistance = 24,
		place = "Outside",
	},
	yardVendingHum = {
		assetId = "rbxassetid://83580452543839",
		group = "Ambient",
		volume = 0.7,
		looped = true,
		rollOffMinDistance = 4,
		rollOffMaxDistance = 30,
		place = "Outside",
	},
	yardBoothRadio = {
		assetId = "rbxassetid://121655014715673",
		group = "Ambient",
		volume = 0.6,
		looped = true,
		rollOffMinDistance = 4,
		rollOffMaxDistance = 32,
		place = "Outside",
	},
	yardTraffic = {
		assetId = "rbxassetid://105519274707699",
		group = "Ambient",
		volume = 1.2,
		looped = true,
		rollOffMinDistance = 40,
		rollOffMaxDistance = 360,
		place = "Outside",
	},
	-- A broken tube's electric zap as it blinks.
	officeLightZap = {
		assetId = "rbxassetid://84566428590094",
		group = "SFX",
		volume = 0.4,
		rollOffMaxDistance = 30,
		maxConcurrent = 2,
	},
	-- An old office phone ringing in an empty room.
	officePhoneRing = {
		assetId = "rbxassetid://137552094086969",
		group = "Ambient",
		volume = 0.7,
		rollOffMaxDistance = 70,
		maxConcurrent = 1,
	},
	-- An elevator's ding, nobody inside.
	officeElevatorDing = {
		assetId = "rbxassetid://128966492979709",
		group = "Ambient",
		volume = 0.7,
		rollOffMaxDistance = 90,
		maxConcurrent = 1,
	},
	-- The exterior anomalies (OfficeAnomalySystem): a parked car's engine ticking as it cools (looped, at the car), the
	-- guard booth TV's faint static (looped), and the lobby's automatic doors sliding open for nobody.
	carTick = {
		assetId = "rbxassetid://127728592892514",
		group = "SFX",
		volume = 0.5,
		looped = true,
		rollOffMaxDistance = 40,
	},
	tvStatic = {
		assetId = "rbxassetid://90442376147683",
		group = "Ambient",
		volume = 0.3,
		looped = true,
		rollOffMaxDistance = 25,
	},
	autoDoor = {
		assetId = "rbxassetid://100859403341825",
		group = "SFX",
		volume = 0.6,
		rollOffMaxDistance = 60,
		maxConcurrent = 1,
	},
	-- Someone typing (looped); it stops when you come close.
	officeTyping = {
		assetId = "rbxassetid://71155319819913",
		group = "Ambient",
		volume = 0.5,
		looped = true,
		rollOffMaxDistance = 35,
	},
}

-- The beds' sweeteners, scattered round the listener by OfficeAmbienceSystem (positional, each kind on its own
-- schedule: OfficeAtmosphereConstants.SWEETENER_EVERY), the office's while the listener is inside and the yard's
-- while outside, each pinned to its place. The volume is the bed plan's gain for that kind, doubled for the 12-30
-- studs it plays from.
local SWEETENERS: { [string]: { string } } = {
	ceilingTick = { "officeCeilingTick1", "officeCeilingTick3" },
	drawer = { "officeDrawer2", "officeDrawer3" },
	farDing = { "officeFarDing1", "officeFarDing3" },
	typeKey = { "officeTypeKey1", "officeTypeKey2" },
	floorCreak = { "officeFloorCreak1", "officeFloorCreak2" },
	musicBox = { "officeMusicBox" },
	pipeKnock = { "officePipeKnock1", "officePipeKnock3" },
}
-- The yard's (round-2 picks, each the cleaned event alone; the moth and the trolley were dropped): no voice, no
-- bark, no sparkle. Each plays FROM its source, not round the listener: a point in one of the emitter volumes
-- tagged with its kind (OfficeDecorConstants.AmbientKind: owls in the treeline, the fence line, the asphalt, the
-- road side) within the sound's rollOffMaxDistance; with none in reach it stays quiet.
local YARD_SWEETENERS: { [string]: { string } } = {
	owl = { "yardOwl1", "yardOwl2", "yardOwl3" },
	fenceRattle = { "yardFence1", "yardFence2", "yardFence3" },
	canRoll = { "yardCan1", "yardCan2", "yardCan3" },
	farCar = { "yardFarCar1", "yardFarCar2", "yardFarCar3" },
}
local SWEETENER_IDS: { [string]: { assetId: string, volume: number } } = {
	officeCeilingTick1 = { assetId = "rbxassetid://90054667378931", volume = 1 },
	officeCeilingTick3 = { assetId = "rbxassetid://128051660338746", volume = 1 },
	officeDrawer2 = { assetId = "rbxassetid://107260118147391", volume = 0.71 },
	officeDrawer3 = { assetId = "rbxassetid://104561368796784", volume = 0.71 },
	officeFarDing1 = { assetId = "rbxassetid://136430418224601", volume = 0.63 },
	officeFarDing3 = { assetId = "rbxassetid://93550627893791", volume = 0.63 },
	officeTypeKey1 = { assetId = "rbxassetid://139517575553683", volume = 0.8 },
	officeTypeKey2 = { assetId = "rbxassetid://82181495537278", volume = 0.8 },
	officeFloorCreak1 = { assetId = "rbxassetid://133123667480314", volume = 1.12 },
	officeFloorCreak2 = { assetId = "rbxassetid://137288427921178", volume = 1.12 },
	officeMusicBox = { assetId = "rbxassetid://105959478172535", volume = 0.63 },
	officePipeKnock1 = { assetId = "rbxassetid://130272101989143", volume = 1.41 },
	officePipeKnock3 = { assetId = "rbxassetid://96147688698929", volume = 1.41 },
}
-- Per kind: the full-volume and the silent distance (an owl carries from the trees, a can only across the asphalt).
local YARD_ROLL_OFF: { [string]: { min: number, max: number } } = {
	owl = { min = 25, max = 220 },
	fenceRattle = { min = 6, max = 70 },
	canRoll = { min = 5, max = 50 },
	farCar = { min = 40, max = 300 },
}
local YARD_SWEETENER_IDS: { [string]: { assetId: string, volume: number, kind: string } } = {
	yardOwl1 = { assetId = "rbxassetid://137993527520416", volume = 1.2, kind = "owl" },
	yardOwl2 = { assetId = "rbxassetid://87944183924375", volume = 1.2, kind = "owl" },
	yardOwl3 = { assetId = "rbxassetid://83757279069045", volume = 1.2, kind = "owl" },
	yardFence1 = { assetId = "rbxassetid://125440827106466", volume = 1, kind = "fenceRattle" },
	yardFence2 = { assetId = "rbxassetid://107004648452810", volume = 1, kind = "fenceRattle" },
	yardFence3 = { assetId = "rbxassetid://83171628900193", volume = 1, kind = "fenceRattle" },
	yardCan1 = { assetId = "rbxassetid://139162091233759", volume = 0.9, kind = "canRoll" },
	yardCan2 = { assetId = "rbxassetid://100041370534179", volume = 0.9, kind = "canRoll" },
	yardCan3 = { assetId = "rbxassetid://100260984763684", volume = 0.9, kind = "canRoll" },
	yardFarCar1 = { assetId = "rbxassetid://121373335447550", volume = 1, kind = "farCar" },
	yardFarCar2 = { assetId = "rbxassetid://137537067308905", volume = 1, kind = "farCar" },
	yardFarCar3 = { assetId = "rbxassetid://96717361744878", volume = 1, kind = "farCar" },
}
for id, row in SWEETENER_IDS do
	SOUNDS[id] = {
		assetId = row.assetId,
		group = "Ambient",
		volume = row.volume,
		pitch = { min = 0.95, max = 1.05 },
		rollOffMaxDistance = 80,
		maxConcurrent = 2,
		place = "Building",
	}
end
for id, row in YARD_SWEETENER_IDS do
	local rollOff = YARD_ROLL_OFF[row.kind]
	SOUNDS[id] = {
		assetId = row.assetId,
		group = "Ambient",
		volume = row.volume,
		pitch = { min = 0.95, max = 1.05 },
		rollOffMinDistance = rollOff.min,
		rollOffMaxDistance = rollOff.max,
		maxConcurrent = 2,
		place = "Outside",
	}
end

-- The loop each fixed emitter kind plays (OfficeDecorConstants.AmbientKind), by the emitter's AmbientKind attribute.
local EMITTER_LOOPS: { [string]: string } = {
	lampBuzz = "yardLampBuzz",
	vendingHum = "yardVendingHum",
	boothRadio = "yardBoothRadio",
	roadSide = "yardTraffic",
}

for id, def in SOUNDS do
	if def.assetId ~= PENDING and not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	PENDING = PENDING,
	SOUNDS = table.freeze(SOUNDS),
	-- The bed's looped layers (each its own SoundServiceClient ambience layer, named by its id).
	BED = table.freeze({ "officeBedHum", "officeBedTube", "officeBedAir", "officeBedColour" }),
	YARD_BED = table.freeze({ "yardBedLamp", "yardBedWind", "yardBedCrickets" }),
	SWEETENERS = table.freeze(SWEETENERS),
	YARD_SWEETENERS = table.freeze(YARD_SWEETENERS),
	EMITTER_LOOPS = table.freeze(EMITTER_LOOPS),
	ZAP = "officeLightZap",
	PHONE = "officePhoneRing",
	ELEVATOR = "officeElevatorDing",
	TYPING = "officeTyping",
	CAR_TICK = "carTick",
	TV_STATIC = "tvStatic",
	AUTO_DOOR = "autoDoor",
})
