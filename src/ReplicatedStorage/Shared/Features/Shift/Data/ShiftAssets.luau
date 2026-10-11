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
	-- The truck's horn: quota met, and the shift's end.
	shiftTruckHorn = { assetId = "rbxassetid://79879032987879", group = "SFX", volume = 1 },
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
	shiftStamp = { assetId = PENDING, group = "UI", volume = 0.9 },
}

local CUE_SOUNDS: { [string]: string } = {
	shiftStart = "shiftPunchIn",
	quotaMet = "shiftTruckHorn",
	tierUp = "shiftTierSting",
	warning = "shiftWarningChime",
	overtime = "shiftOvertimeSting",
	clockOut = "shiftClockOutHorn",
	shiftEnd = "shiftTruckHorn",
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
	TICKING = "shiftTicking",
	COUNTDOWN_TICK = "shiftCountdownTick",
})
