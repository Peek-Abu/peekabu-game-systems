--!strict
--[=[
	AnimationOccupantRegistry: the `occupant` animation domain (Cleanup Crew's Mr. Harlow), composed by
	AnimationRegistry. Built from OccupantAssets.ANIMATIONS (the one home of his animation ids, spec §7), uploaded
	slots only, so a pending slot never reaches the registry's canonical-id assert and he keeps the base clips.

	@class AnimationOccupantRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local OccupantAnimationUtils = require(ReplicatedStorage.Shared.Features.Occupant.Utils.OccupantAnimationUtils)

return OccupantAnimationUtils.domain(OccupantAssets.ANIMATIONS, OccupantAssets.PENDING)
