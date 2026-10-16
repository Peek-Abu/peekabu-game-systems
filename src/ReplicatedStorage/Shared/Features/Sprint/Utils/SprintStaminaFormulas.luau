--!strict
--[=[
	SprintStaminaFormulas: the stamina bar (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §3).
	Sprinting drains a full bar in STAMINA_SECONDS; after REGEN_DELAY seconds without draining it refills, empty to full
	in REGEN_SECONDS. A bar run dry is exhausted until it refills to RESTART_FRACTION (no stutter-sprinting on a sliver).
	Pure: `step` returns a new state.

	@class SprintStaminaFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SprintConstants = require(ReplicatedStorage.Shared.Features.Sprint.Data.SprintConstants)

export type Stamina = {
	-- 0 (empty) to 1 (full).
	stamina: number,
	-- Seconds since the bar last drained.
	rested: number,
	exhausted: boolean,
}

local SprintStaminaFormulas = {}

function SprintStaminaFormulas.fresh(): Stamina
	return { stamina = 1, rested = math.huge, exhausted = false }
end

--[=[
	The bar `dt` seconds on, drained when `draining` (sprinting and moving). A non-finite or negative `dt` changes
	nothing.
]=]
function SprintStaminaFormulas.step(state: Stamina, dt: number, draining: boolean): Stamina
	if not (dt > 0 and dt < math.huge) then
		return table.clone(state)
	end
	if draining then
		local stamina = math.max(0, state.stamina - dt / SprintConstants.STAMINA_SECONDS)
		-- A hair of floating-point leftover counts as dry.
		if stamina < 1e-6 then
			stamina = 0
		end
		return { stamina = stamina, rested = 0, exhausted = state.exhausted or stamina <= 0 }
	end
	local rested = state.rested + dt
	local stamina = state.stamina
	if rested > SprintConstants.REGEN_DELAY then
		local refilling = math.min(dt, rested - SprintConstants.REGEN_DELAY)
		stamina = math.min(1, stamina + refilling / SprintConstants.REGEN_SECONDS)
		if stamina > 1 - 1e-6 then
			stamina = 1
		end
	end
	local exhausted = state.exhausted and stamina < SprintConstants.RESTART_FRACTION
	return { stamina = stamina, rested = rested, exhausted = exhausted }
end

--[=[
	Whether a sprint may start (or go on) with this bar.
]=]
function SprintStaminaFormulas.canStart(state: Stamina): boolean
	return not state.exhausted and state.stamina > 0
end

return SprintStaminaFormulas
