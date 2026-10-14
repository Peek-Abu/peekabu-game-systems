--!strict
--[=[
	AnimationEmployeeRegistry: the `employee` animation domain (Cleanup Crew's playable employees), composed
	by AnimationRegistry. Each employee's own locomotion clips live here; EmployeeRegistry names them by key
	(`locomotion`), and the character's Animate binding plays them in place of the stock idle/walk/run.

	Pippa's clips (uploaded under the Icey Labs group, sources in `characters/pippa/anim/`) are authored
	relative to her own T-pose rest and carry no retargeting rig data, so `Workspace.Retargeting` does not
	touch them. They are root-in-place loops whose feet plant at a measured speed at 1x playback (walk
	1.27 st/s, run 1.52 st/s); EmployeeRegistry carries those numbers for the stride scaling.

	All entries are Core + `ambient`, like the stock locomotion: gameplay clips (carry, vacuum, actions)
	sit above them, and a bulk combat stop never kills them.

	@class AnimationEmployeeRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

type AnimationDomain = AnimationTypes.AnimationDomain

local function locomotion(assetId: string): AnimationTypes.AnimationDef
	local def: AnimationTypes.AnimationDef = {
		assetId = assetId,
		priority = Enum.AnimationPriority.Core,
		looped = true,
		interruption = "ambient",
	}
	return table.freeze(def)
end

local AnimationEmployeeRegistry: AnimationDomain = table.freeze({
	-- Pippa Idle v1: 3.0 s loop, feet fixed.
	pippaidle = locomotion("rbxassetid://75845395212929"),
	-- Pippa Walk v1: 1.9 s loop (2 cycles), feet planted at 1.27 st/s at 1x.
	pippawalk = locomotion("rbxassetid://93025706307245"),
	-- Pippa Run v1: 1.03 s loop (2 cycles), feet planted at 1.52 st/s at 1x.
	pipparun = locomotion("rbxassetid://106530900825479"),
})

return AnimationEmployeeRegistry
