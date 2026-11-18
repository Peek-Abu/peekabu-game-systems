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
	-- A vacuum motor's whine (looped at the pile; its pitch rises with the pile's progress). Owner tryout round-2 pick
	-- B (2026-11-17): a small cartoon canister vacuum, whirring motor with airy suction, a 4 s seamless loop (ElevenLabs
	-- SFX, Starter plan, Icey Labs; OGG, -18 LUFS). Was 107917509032443.
	vacuumWhine = {
		assetId = "rbxassetid://134982892215570",
		group = "SFX",
		bus = "Action",
		volume = 0.45,
		looped = true,
		rollOffMaxDistance = 60,
	},
	-- The motor winding down when the whine stops (started at the whine's pitch).
	vacuumStop = {
		assetId = "rbxassetid://77219631283212",
		group = "SFX",
		bus = "Action",
		volume = 0.45,
		rollOffMaxDistance = 60,
	},
	-- The pile's last bit going up the hose: a goo slurp ending in a wet cartoon pop. Owner tryout round-2 pick A
	-- (2026-11-17; ElevenLabs SFX, Starter plan, Icey Labs; -16 LUFS short-term). Was 91652457132086.
	vacuumPop = {
		assetId = "rbxassetid://113118023946403",
		group = "SFX",
		bus = "Action",
		volume = 0.8,
		pitch = { min = 0.95, max = 1.1 },
		rollOffMaxDistance = 60,
	},
	-- The canister's Gloom gauge rising, and the chime when the contract is met (the gauge is full).
	-- (Mix 2026-11-10: it can fire every GLOOM_TICK_GAP = 0.15 s, so each tick is pitched a little differently.)
	canisterTick = {
		assetId = "rbxassetid://112926891018046",
		group = "UI",
		volume = 0.5,
		pitch = { min = 0.96, max = 1.04 },
	},
	canisterChime = { assetId = "rbxassetid://134210659787428", group = "UI", volume = 0.5 },
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
