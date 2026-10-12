--!strict
-- Original vacuum clip sources: design/animations/vacuum/final.
-- Intentionally no entries until the exact four-asset batch has approval, game owner
-- upload IDs and native Animator length/contact verification. Foreign and fake IDs
-- must never fill this domain. The server consumer checks readiness before granting.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)
local AnimationVacuumRegistry: AnimationTypes.AnimationDomain = {}
return table.freeze(AnimationVacuumRegistry)
