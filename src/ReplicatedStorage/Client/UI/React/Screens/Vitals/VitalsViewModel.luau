--!strict
--[=[
	VitalsViewModel: the pure derivation behind the Vitals HUD.

	Every decision the HUD makes lives here — XP progress from the stats slice, health fraction and
	label from raw numbers — so `VitalsHud` stays a dumb renderer with nothing worth unit-testing.
	This is the split the whole UI framework leans on: LOGIC in a specced view-model, INSTANCES in an
	exempt component (docs/testing.md).

	Plain functions over plain values (no atoms, no Instances, no React) so they're callable from a
	spec and from inside a React binding transform alike — the health path runs on every
	`HealthChanged`, so it must be cheap and allocation-light.

	@class VitalsViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local StatFormulas = require(ReplicatedStorage.Shared.Features.Stat.Utils.StatFormulas)

--[=[
	XP/level readout. `loading` is true until the stats slice first syncs — the HUD shows a placeholder
	rather than a convincing but wrong "level 1, 0 XP".
]=]
export type XpDisplay = {
	loading: boolean,
	level: number,
	fraction: number, -- 0..1, always 1 at the level cap
	label: string,
}

export type HealthDisplay = {
	fraction: number, -- 0..1, clamped
	label: string,
}

-- Shown instead of a number while the slice is unsynced.
local UNSYNCED_LABEL = "—"

local VitalsViewModel = {}

--[=[
	Derives the XP/level readout from the stats slice (nil before the first sync).
	@param stats PlayerDataTypes.StatsSlice? -- the synced slice, or nil while loading
	@return XpDisplay
]=]
function VitalsViewModel.fromStats(stats: PlayerDataTypes.StatsSlice?): XpDisplay
	if stats == nil then
		return { loading = true, level = 0, fraction = 0, label = UNSYNCED_LABEL }
	end

	local progress = StatFormulas.progress(stats.totalXp)
	local xpToNext = progress.xpToNext
	if xpToNext == nil then
		-- At the level cap there is no "next" — a full bar reads better than an empty one.
		return { loading = false, level = progress.level, fraction = 1, label = "MAX" }
	end

	return {
		loading = false,
		level = progress.level,
		fraction = math.clamp(progress.xpIntoLevel / xpToNext, 0, 1),
		label = `{progress.xpIntoLevel} / {xpToNext}`,
	}
end

--[=[
	Derives the health readout. Guards the two cases a live Humanoid actually produces: a zero
	MaxHealth (during character setup/teardown) must not divide by zero, and overheal/negative health
	must not push the bar outside its track.
	@param current number -- Humanoid.Health
	@param max number -- Humanoid.MaxHealth
	@return HealthDisplay
]=]
function VitalsViewModel.fromHealth(current: number, max: number): HealthDisplay
	local fraction = if max > 0 then math.clamp(current / max, 0, 1) else 0
	return {
		fraction = fraction,
		label = `{math.round(current)} / {math.round(max)}`,
	}
end

return VitalsViewModel
