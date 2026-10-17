--!strict
--[=[
	ShiftAssets: every asset id the Shift feature uses (Cleanup Crew spec §7: "Asset id literals live only in each
	feature's Data/<Feature>Assets"). An id is PENDING ("") until the developer uploads the staged file (the M3
	plan's "Asset staging" appendix) and pastes `rbxassetid://<n>` here. A pending sound is never registered, so
	every player of it (they all check SoundRegistry.has) stays silent. Registers the uploaded sounds at load on
	whichever realm requires this first (guarded). CUE_SOUNDS says which sound each shift moment plays
	(ShiftCueUtils.Cue → id).

	Static data + registration (spec-exempt).

	@class ShiftAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local PENDING = ""

local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	-- A punch-clock "ka-chunk" when the shift starts.
	shiftPunchIn = { assetId = "rbxassetid://109228401071501", group = "SFX", volume = 0.8 },
	-- The truck's horn: the shift's end.
	shiftTruckHorn = { assetId = "rbxassetid://79879032987879", group = "SFX", volume = 1 },
	-- The contract met mid-shift: the company motif F-A-C-Bb on clarinet over an oom-pah-pah, a ta-da and a register
	-- ding, "you did it, keep going" (round-3 pick M1, in-house; 2D, over the office bed).
	shiftContractMet = { assetId = "rbxassetid://75263082800024", group = "SFX", volume = 0.9 },
	-- The performance review's jingle as it opens (2D, once; JINGLE_SOUNDS by ShiftCueUtils.jingle), in-house: met (round-2
	-- C, spooky-first waltz into the relief), met with overtime pay (round-3 O1: C bigger, harp gliss, timpani, coins), and
	-- missed (round-3 F3: the same record slowing to a stop before the relief lands).
	shiftResultsMet = { assetId = "rbxassetid://74050052665633", group = "SFX", volume = 0.9 },
	shiftResultsOvertime = { assetId = "rbxassetid://122358530335366", group = "SFX", volume = 0.9 },
	shiftResultsMissed = { assetId = "rbxassetid://136628215898951", group = "SFX", volume = 0.9 },
	-- A low brass sting when the pressure tier rises.
	shiftTierSting = { assetId = "rbxassetid://136159590763818", group = "SFX", volume = 0.7 },
	-- An office PA chime before overtime.
	shiftWarningChime = { assetId = "rbxassetid://126147740959997", group = "UI", volume = 0.8 },
	shiftOvertimeSting = { assetId = "rbxassetid://95766845390235", group = "SFX", volume = 0.9 },
	-- The overtime layer: a clock ticking under everything (looped).
	shiftTicking = { assetId = "rbxassetid://118452299844030", group = "Music", volume = 0.5, looped = true },
	-- Two honks: someone clocked out.
	shiftClockOutHorn = { assetId = "rbxassetid://121905159563801", group = "SFX", volume = 1 },
	shiftCountdownTick = { assetId = "rbxassetid://135218748578686", group = "UI", volume = 0.6, maxConcurrent = 2 },
	-- The toast styles' sounds (ShiftConstants.TOAST_STYLES): a paper rustle and a rubber stamp.
	shiftStickyNote = { assetId = "rbxassetid://99429190384090", group = "UI", volume = 0.6 },
	shiftStamp = { assetId = "rbxassetid://121483921177102", group = "UI", volume = 0.9 },
}

local CUE_SOUNDS: { [string]: string } = {
	shiftStart = "shiftPunchIn",
	quotaMet = "shiftContractMet",
	tierUp = "shiftTierSting",
	warning = "shiftWarningChime",
	overtime = "shiftOvertimeSting",
	clockOut = "shiftClockOutHorn",
	shiftEnd = "shiftTruckHorn",
}

-- The review's jingle per ShiftCueUtils.Jingle.
local JINGLE_SOUNDS: { [string]: string } = {
	met = "shiftResultsMet",
	overtime = "shiftResultsOvertime",
	missed = "shiftResultsMissed",
}

for id, def in SOUNDS do
	if def.assetId ~= PENDING and not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end

return table.freeze({
	PENDING = PENDING,
	SOUNDS = table.freeze(SOUNDS),
	CUE_SOUNDS = table.freeze(CUE_SOUNDS),
	JINGLE_SOUNDS = table.freeze(JINGLE_SOUNDS),
	TICKING = "shiftTicking",
	COUNTDOWN_TICK = "shiftCountdownTick",
})
