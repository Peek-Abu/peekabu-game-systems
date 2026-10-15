--!strict
--[=[
	AnimationCarryRegistry: per-kind OVERRIDES of how a carried kind is held. Empty by design.

	Holds are chosen automatically from what can be seen of the item and its weight against the carrier's body
	(AnimationCarryHoldRules) and planned on its real surface (AnimationCarryContactUtils), so a new prop needs no
	entry here. Pin a kind only when a game design wants a hold the rules would not pick; the art can also pin its
	own (`CarryHold` attribute on the template). An override is tried first; the rules' order follows it.

	@class AnimationCarryRegistry
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

local overrides: { [string]: AnimationTypes.CarryStyle } = {}
table.freeze(overrides)

local AnimationCarryRegistry = {}

--[=[
	The hold pinned for `kind`, or nil when the rules decide.
]=]
function AnimationCarryRegistry.get(kind: string): AnimationTypes.CarryStyle?
	return overrides[kind]
end

return table.freeze(AnimationCarryRegistry)
