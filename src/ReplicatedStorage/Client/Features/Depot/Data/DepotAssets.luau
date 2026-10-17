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
	depotHubTheme = { assetId = "rbxassetid://127824044953174", group = "Music", volume = 1, looped = true },
}

for id, def in SOUNDS do
	if not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	SOUNDS = table.freeze(SOUNDS),
	HUB_THEME = "depotHubTheme",
})
