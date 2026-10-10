--!strict
--[=[
	OfficeAssets: every asset id the Office feature uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"): the fluorescent hum, a broken light's zap, and the ambient dread (a phone
	ringing, the elevator's ding, typing). Client-only: nothing on the server plays them. An id is PENDING ("")
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
	-- Buzzing fluorescent tubes under everything (looped ambience).
	officeHum = { assetId = PENDING, group = "Ambient", volume = 0.35, looped = true },
	-- A broken tube's electric zap as it blinks.
	officeLightZap = { assetId = PENDING, group = "SFX", volume = 0.4, rollOffMaxDistance = 30, maxConcurrent = 2 },
	-- An old office phone ringing in an empty room.
	officePhoneRing = { assetId = PENDING, group = "Ambient", volume = 0.7, rollOffMaxDistance = 70, maxConcurrent = 1 },
	-- An elevator's ding, nobody inside.
	officeElevatorDing = {
		assetId = PENDING,
		group = "Ambient",
		volume = 0.7,
		rollOffMaxDistance = 90,
		maxConcurrent = 1,
	},
	-- Someone typing (looped); it stops when you come close.
	officeTyping = { assetId = PENDING, group = "Ambient", volume = 0.5, looped = true, rollOffMaxDistance = 35 },
}

for id, def in SOUNDS do
	if def.assetId ~= PENDING and not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	PENDING = PENDING,
	SOUNDS = table.freeze(SOUNDS),
	HUM = "officeHum",
	ZAP = "officeLightZap",
	PHONE = "officePhoneRing",
	ELEVATOR = "officeElevatorDing",
	TYPING = "officeTyping",
})
