--!strict
--[=[
	SprintViewModel: the stamina bar (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §3). It shows
	only while the bar is not full, never while the HUD is hidden; under RESTART_FRACTION it reads low (stamp red: a
	sprint will not start yet once run dry). Pure.

	@class SprintViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SprintConstants = require(ReplicatedStorage.Shared.Features.Sprint.Data.SprintConstants)

export type BarView = {
	fill: number,
	low: boolean,
}

local SprintViewModel = {}

function SprintViewModel.bar(stamina: number, hudHidden: boolean): BarView?
	if hudHidden or not (stamina < 1) then
		return nil
	end
	local fill = math.clamp(stamina, 0, 1)
	return { fill = fill, low = fill < SprintConstants.RESTART_FRACTION }
end

return SprintViewModel
