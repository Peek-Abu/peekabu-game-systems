--!strict
--[=[
	DepotAssets: every asset id the Depot feature's client uses (Cleanup Crew spec §7: "Asset id literals live only in
	each feature's Data/<Feature>Assets"): the hub's record. Client-only. Registers the uploaded sounds at load (guarded).

	Static data + registration (spec-exempt).

	@class DepotAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- The depot lounge record (round-2 pick A, in-house): F major, 96 bpm cha-cha, the company motif F-A-C-Bb on
	-- clarinet over harpsichord and pizz; a bar-exact 60 s OGG loop. 2D, the music slot, while you are in the hub
	-- (OfficeAtmosphereSystem).
	depotHubTheme = { assetId = "rbxassetid://113418650275760", group = "Music", volume = 1, looped = true },
	-- The shift bell by the trucks (DepotSpotConstants.BELL_SOUND): the office's far ding, played at the bell for
	-- everyone in the hub.
	depotShiftBell = {
		assetId = "rbxassetid://136430418224601",
		group = "SFX",
		volume = 1.1,
		pitch = { min = 0.97, max = 1.03 },
		maxConcurrent = 3,
		rollOffMinDistance = 18,
		rollOffMaxDistance = 140,
	},
	-- The delivery truck driving past the yard (DepotDriveBySystem): the shift truck's honk, far away.
	depotDriveByHorn = {
		assetId = "rbxassetid://121905159563801",
		group = "SFX",
		volume = 0.7,
		pitch = { min = 0.92, max = 1.0 },
		maxConcurrent = 1,
		rollOffMinDistance = 30,
		rollOffMaxDistance = 220,
	},
}

for id, def in SOUNDS do
	if not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

-- The radio's music-note flipbook image (see RADIO_NOTES below); nil until uploaded.
local RADIO_NOTES: string? = nil

return table.freeze({
	SOUNDS = table.freeze(SOUNDS),
	HUB_THEME = "depotHubTheme",
	-- The radio's music notes: a 2x2 flipbook (two notes, a beamed pair, a sparkle) in gold and mint
	-- (design/production-art/hub-dressing/radio_notes_flipbook.png). Nil until the owner OKs the upload: no notes.
	RADIO_NOTES = RADIO_NOTES,
})
