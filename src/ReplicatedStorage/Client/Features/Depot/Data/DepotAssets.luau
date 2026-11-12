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

-- The radio's music-note flipbook image (see RADIO_NOTES below): Icey Labs decal 81235055229989, its image.
local RADIO_NOTES: string? = "rbxassetid://84887799913082"

return table.freeze({
	SOUNDS = table.freeze(SOUNDS),
	HUB_THEME = "depotHubTheme",
	-- The radio's music notes: a 2x2 flipbook (two notes, a beamed pair, a sparkle) in gold and mint
	-- (design/production-art/hub-dressing/radio_notes_flipbook.png). Uploaded with the owner's OK (2026-11-11).
	RADIO_NOTES = RADIO_NOTES,
	-- The Supply Counter clerk's clips (DepotClerkSystem; design/animations/clerk, Icey Labs, uploaded with the owner's
	-- OK 2026-11-11): the active idle (looped), the stamp fidget (v6, markers Thunk and Lift), the stretch fidget and
	-- the wave.
	CLERK_IDLE = "rbxassetid://111793457366391",
	CLERK_STAMP = "rbxassetid://109774578542575",
	CLERK_STRETCH = "rbxassetid://89323328078889",
	CLERK_GREET = "rbxassetid://105235060315952",
})
