--!strict
--[=[
	OfficeAssets: every asset id the Office feature uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"): the office bed (four looped beds and the sweetener one-shots code scatters round
	you), a broken light's zap, and the ambient dread (a phone ringing, the elevator's ding, typing). Client-only: nothing on the server plays them. An id is PENDING ("")
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
	-- the 5th, HVAC air, and a minor-3rd cello colour that comes and goes.
	officeBedHum = { assetId = "rbxassetid://78387618185725", group = "Ambient", volume = 1, looped = true },
	officeBedTube = { assetId = "rbxassetid://119618262674325", group = "Ambient", volume = 1, looped = true },
	officeBedAir = { assetId = "rbxassetid://75154883738037", group = "Ambient", volume = 1, looped = true },
	officeBedColour = { assetId = "rbxassetid://88550740744264", group = "Ambient", volume = 1, looped = true },
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
	-- Someone typing (looped); it stops when you come close.
	officeTyping = {
		assetId = "rbxassetid://71155319819913",
		group = "Ambient",
		volume = 0.5,
		looped = true,
		rollOffMaxDistance = 35,
	},
}

-- The bed's sweeteners, scattered round the listener by OfficeAmbienceSystem (positional, each kind on its own
-- schedule: OfficeAtmosphereConstants.SWEETENER_EVERY). The volume is the bed plan's gain for that kind, doubled for
-- the 12-30 studs it plays from.
local SWEETENERS: { [string]: { string } } = {
	ceilingTick = { "officeCeilingTick1", "officeCeilingTick3" },
	drawer = { "officeDrawer2", "officeDrawer3" },
	farDing = { "officeFarDing1", "officeFarDing3" },
	typeKey = { "officeTypeKey1", "officeTypeKey2" },
	floorCreak = { "officeFloorCreak1", "officeFloorCreak2" },
	musicBox = { "officeMusicBox" },
	pipeKnock = { "officePipeKnock1", "officePipeKnock3" },
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
for id, row in SWEETENER_IDS do
	SOUNDS[id] = {
		assetId = row.assetId,
		group = "Ambient",
		volume = row.volume,
		pitch = { min = 0.95, max = 1.05 },
		rollOffMaxDistance = 80,
		maxConcurrent = 2,
	}
end

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
	SWEETENERS = table.freeze(SWEETENERS),
	ZAP = "officeLightZap",
	PHONE = "officePhoneRing",
	ELEVATOR = "officeElevatorDing",
	TYPING = "officeTyping",
})
