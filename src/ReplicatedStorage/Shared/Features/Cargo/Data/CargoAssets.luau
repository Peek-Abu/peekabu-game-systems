--!strict
--[=[
	CargoAssets: every asset id the Cargo feature uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"). An id is PENDING ("") until the developer uploads the staged file (the M3
	plan's "Asset staging" appendix); a pending sound is never registered, so playing it is silent (the server's
	SoundServiceServer:playAt and every client caller check SoundRegistry.has). Registers the uploaded sounds at
	load on whichever realm requires this first (guarded): the server plays the drop, rattle and search sounds,
	the client the rest.

	Static data + registration (spec-exempt).

	@class CargoAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local PENDING = ""

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- Banking: the item whooshing into the truck, then a cash-register "cha-ching" at the bed.
	cargoSwoosh = { assetId = "rbxassetid://130905132369531", group = "SFX", volume = 0.6, rollOffMaxDistance = 60 },
	cargoChaChing = { assetId = "rbxassetid://110411418261024", group = "SFX", volume = 0.9, rollOffMaxDistance = 80 },
	-- Your own hands and pockets.
	cargoPickup = { assetId = "rbxassetid://95113352299095", group = "SFX", volume = 0.5 },
	cargoPocket = { assetId = "rbxassetid://9121003380", group = "UI", volume = 0.6 },
	-- Drops, by trait then weight (CargoFeedbackUtils.dropSound); heard by everyone near.
	cargoThudLight = {
		assetId = "rbxassetid://82279308966281",
		group = "SFX",
		volume = 0.7,
		pitch = { min = 0.9, max = 1.1 },
		rollOffMaxDistance = 70,
		maxConcurrent = 4,
	},
	cargoThudHeavy = {
		assetId = "rbxassetid://77274323915881",
		group = "SFX",
		volume = 1,
		pitch = { min = 0.9, max = 1.05 },
		rollOffMaxDistance = 90,
		maxConcurrent = 3,
	},
	cargoShatter = {
		assetId = "rbxassetid://9114597147",
		group = "SFX",
		volume = 0.9,
		rollOffMaxDistance = 90,
		maxConcurrent = 3,
	},
	cargoSplash = {
		assetId = "rbxassetid://87333978366779",
		group = "SFX",
		volume = 1,
		rollOffMaxDistance = 120,
		maxConcurrent = 2,
	},
	-- A rattly item's pulse while carried, and rummaging through a desk or locker.
	cargoRattle = {
		assetId = "rbxassetid://103584623487822",
		group = "SFX",
		volume = 0.5,
		pitch = { min = 0.9, max = 1.15 },
		rollOffMaxDistance = 40,
		maxConcurrent = 4,
	},
	-- The loot loop (docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md §5), in-house (round-2 and -3
	-- picks; the Icey Labs uploads). A buried item popping out of its pile: family C, the same dust clean + pop on every
	-- tier and only the F-major value layer grows (one note, a 3rd, C-F-A, the full motif), by the item's base value
	-- (CargoLootFeedbackFormulas.revealTier; REVEAL_SOUNDS). An appraisal: tag flick + stamp + vibes F6 ding (A1; its
	-- sticky slip is silent on purpose, so this is its only sound); a jackpot appraisal starts with A1, holds a breath,
	-- then pays off (red JACKPOT stamp, glock run, register, coins). A buried pile's glint: a music-box twinkle, mixed at
	-- -24 LUFS (meant to be easy to miss).
	cargoRevealLow = { assetId = "rbxassetid://103029093745671", group = "SFX", volume = 0.8, rollOffMaxDistance = 60 },
	cargoRevealMid = { assetId = "rbxassetid://127359448338833", group = "SFX", volume = 0.8, rollOffMaxDistance = 60 },
	cargoRevealHigh = { assetId = "rbxassetid://114181554867050", group = "SFX", volume = 0.8, rollOffMaxDistance = 70 },
	cargoRevealJackpot = {
		assetId = "rbxassetid://119747942358809",
		group = "SFX",
		volume = 0.8,
		rollOffMaxDistance = 80,
	},
	cargoAppraise = { assetId = "rbxassetid://78325157618409", group = "SFX", volume = 0.8, rollOffMaxDistance = 40 },
	cargoJackpot = { assetId = "rbxassetid://112524045440299", group = "SFX", volume = 0.9, rollOffMaxDistance = 60 },
	cargoGlint = {
		assetId = "rbxassetid://100033229972306",
		group = "SFX",
		volume = 0.8,
		rollOffMaxDistance = 20,
		maxConcurrent = 2,
	},
	-- Choosing a hotbar slot (keys 1-5, the d-pad, a tap; equipping the vacuum too): a tab flick + card body, UI tier 1
	-- from the paperwork family (round-3 pick A; 2D, tiny: it plays a lot).
	cargoSelect = { assetId = "rbxassetid://81438361671526", group = "UI", volume = 0.8, maxConcurrent = 2 },
	cargoRummage = {
		assetId = "rbxassetid://9114061295",
		group = "SFX",
		volume = 0.6,
		rollOffMaxDistance = 40,
		maxConcurrent = 3,
	},
}

for id, def in SOUNDS do
	if def.assetId ~= PENDING and not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

-- The reveal sound per value tier (CargoLootFeedbackFormulas.RevealTier).
local REVEAL_SOUNDS: { [string]: string } = {
	low = "cargoRevealLow",
	mid = "cargoRevealMid",
	high = "cargoRevealHigh",
	jackpot = "cargoRevealJackpot",
}

return table.freeze({
	PENDING = PENDING,
	SOUNDS = table.freeze(SOUNDS),
	REVEAL_SOUNDS = table.freeze(REVEAL_SOUNDS),
	SELECT = "cargoSelect",
})
