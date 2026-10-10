--!strict
--[=[
	VacuumAssets: every asset id the Vacuum feature uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"). An id is PENDING ("") until the developer uploads the staged file (the M3
	plan's "Asset staging" appendix); a pending sound is never registered, so playing it is silent. Registers the
	uploaded sounds at load on whichever realm requires this first (guarded).

	Static data + registration (spec-exempt).

	@class VacuumAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local PENDING = ""

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- A vacuum motor's whine (looped at the pile; its pitch rises with the pile's progress).
	vacuumWhine = { assetId = PENDING, group = "SFX", volume = 0.45, looped = true, rollOffMaxDistance = 60 },
	-- The pile's last bit going up the hose: a soft pop.
	vacuumPop = {
		assetId = PENDING,
		group = "SFX",
		volume = 0.8,
		pitch = { min = 0.95, max = 1.1 },
		rollOffMaxDistance = 60,
	},
	-- Your canister taking a pile, and the chime when it is full.
	canisterTick = { assetId = PENDING, group = "UI", volume = 0.5 },
	canisterChime = { assetId = PENDING, group = "UI", volume = 0.8 },
	-- The dust bag popping out at your feet.
	dustBagPop = { assetId = PENDING, group = "SFX", volume = 0.8, rollOffMaxDistance = 40 },
}

for id, def in SOUNDS do
	if def.assetId ~= PENDING and not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	PENDING = PENDING,
	SOUNDS = table.freeze(SOUNDS),
	WHINE = "vacuumWhine",
	POP = "vacuumPop",
})
