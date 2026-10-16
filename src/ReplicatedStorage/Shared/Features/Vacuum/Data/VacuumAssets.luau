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
	vacuumWhine = {
		assetId = "rbxassetid://107917509032443",
		group = "SFX",
		volume = 0.45,
		looped = true,
		rollOffMaxDistance = 60,
	},
	-- The motor winding down when the whine stops (started at the whine's pitch).
	vacuumStop = { assetId = "rbxassetid://77219631283212", group = "SFX", volume = 0.45, rollOffMaxDistance = 60 },
	-- The pile's last bit going up the hose: a soft pop.
	vacuumPop = {
		assetId = "rbxassetid://91652457132086",
		group = "SFX",
		volume = 0.8,
		pitch = { min = 0.95, max = 1.1 },
		rollOffMaxDistance = 60,
	},
	-- The canister's Gloom gauge rising, and the chime when the contract is met (the gauge is full).
	canisterTick = { assetId = "rbxassetid://112926891018046", group = "UI", volume = 0.5 },
	canisterChime = { assetId = "rbxassetid://134210659787428", group = "UI", volume = 0.8 },
}

for id, def in SOUNDS do
	if def.assetId ~= PENDING and not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	PENDING = PENDING,
	-- The backpack hose's corrugated strip (a Beam texture; characters/vacuum/make_hose_texture.py, Icey Labs).
	HOSE_TEXTURE = "rbxassetid://82530981101419",
	-- The Brass Bellows skin's corrugated copper hose (characters/vacuum/skins/brass-bellows, Icey Labs; decal
	-- 87115006823609).
	HOSE_TEXTURE_COPPER = "rbxassetid://79413170105323",
	SOUNDS = table.freeze(SOUNDS),
	WHINE = "vacuumWhine",
	POP = "vacuumPop",
	STOP = "vacuumStop",
})
