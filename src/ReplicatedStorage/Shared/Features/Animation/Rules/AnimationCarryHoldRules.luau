--!strict
--[=[
	AnimationCarryHoldRules: which hold an item gets, decided from what can be seen of it and how heavy it is,
	against THIS carrier's measured body. No per-item tuning: any new prop gets its hold from these rules.

	`choose` returns the styles to try, best first (AnimationCarryContactUtils.plan takes the first one whose planned
	pose passes AnimationCarryPoseRules):

	- `push` only, for anything as heavy as furniture (weight >= PUSH_WEIGHT: the filing cabinet): it stays on the
	  floor and both palms go flat on its near face.
	- `hand` first, for a light item (weight <= ONE_HAND_WEIGHT) a hand can close round: it has a handle
	  (`CarryHandle` on its art) or a level side no wider than GRASP_HANDS hand lengths (the plaque, the stapler). It
	  hangs from the relaxed arm and swings; it is dropped from the list by the planner when it would not clear the
	  floor or the body from a relaxed arm (a 2-stud bag on Pippa), and the hands go under it instead.
	- `under` (the recycling-box hold: palms up on its real bottom) for everything else, the default.
	- `push` before `under` for a heavy item (weight >= HEAVY_WEIGHT) too tall to lift without hiding the carrier's
	  eyes: its top would rise past the middle of the head with the palms an upper arm below the shoulders (the water
	  jug and coffee machine, on Pippa or a stock avatar), and (`instead`) one whose planned lift turns out to hide the
	  eyes (the fish tank on Pippa's short arms). `push` is always the last resort when nothing else fits.

	An item's art may override the choice (`CarryHold` attribute: "hand", "under" or "push"), tried first.

	@class AnimationCarryHoldRules
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)
local AnimationCarryArmUtils = require(ReplicatedStorage.Shared.Features.Animation.Utils.AnimationCarryArmUtils)

type Style = AnimationTypes.CarryStyle

-- What the rules read about an item: the box round its visible parts, its carry weight (CarryRegistry: 0 none, 1.5
-- light, 4 medium, 7 heavy, 10 bulky), whether its art authors a handle, and its art's `CarryHold` override.
export type Item = { size: Vector3, weight: number, handle: boolean, override: Style? }

local STYLES: { [string]: Style } = { hand = "hand", under = "under", push = "push" }
table.freeze(STYLES)

local AnimationCarryHoldRules = {}

AnimationCarryHoldRules.ONE_HAND_WEIGHT = 1.5
AnimationCarryHoldRules.HEAVY_WEIGHT = 7
AnimationCarryHoldRules.PUSH_WEIGHT = 10
-- A hand closes round a level side up to this many hand lengths across.
AnimationCarryHoldRules.GRASP_HANDS = 1.6
-- Where the palms ride under a carried item, below the shoulders, in arm reaches (AnimationCarryContactUtils).
AnimationCarryHoldRules.CARRY_DROP = 0.55

--[=[
	The hold `value` names (the art's `CarryHold` attribute), or nil for anything else.
]=]
function AnimationCarryHoldRules.style(value: unknown): Style?
	return if type(value) == "string" then STYLES[value] else nil
end

--[=[
	Whether one hand can close round the item: it has a handle, or a level side within GRASP_HANDS hand lengths.
]=]
function AnimationCarryHoldRules.graspable(item: Item, rig: AnimationTypes.CarryRig): boolean
	local hand = math.min(rig.right.handLength, rig.left.handLength)
	return item.handle or math.min(item.size.X, item.size.Z) <= AnimationCarryHoldRules.GRASP_HANDS * hand
end

--[=[
	Where an item's top would ride if carried with the palms under it (root Y).
]=]
function AnimationCarryHoldRules.carriedTop(item: Item, rig: AnimationTypes.CarryRig): number
	local shoulderY = (rig.right.shoulder.Y + rig.left.shoulder.Y) / 2
	local reach = math.min(AnimationCarryArmUtils.reach(rig.right), AnimationCarryArmUtils.reach(rig.left))
	return shoulderY - reach * AnimationCarryHoldRules.CARRY_DROP + item.size.Y
end

--[=[
	The styles to try for `item` on `rig`, best first (see the class).
]=]
function AnimationCarryHoldRules.choose(item: Item, rig: AnimationTypes.CarryRig): { Style }
	local order: { Style } = {}
	local function add(style: Style)
		if table.find(order, style) == nil then
			table.insert(order, style)
		end
	end
	if item.override ~= nil then
		add(item.override)
	end
	if item.weight >= AnimationCarryHoldRules.PUSH_WEIGHT then
		add("push")
		return order
	end
	if item.weight <= AnimationCarryHoldRules.ONE_HAND_WEIGHT and AnimationCarryHoldRules.graspable(item, rig) then
		add("hand")
	end
	if
		item.weight >= AnimationCarryHoldRules.HEAVY_WEIGHT
		and AnimationCarryHoldRules.carriedTop(item, rig) > (rig.headBottom + rig.headTop) / 2
	then
		add("push")
	end
	add("under")
	add("push")
	return order
end

--[=[
	The style to hold a heavy item by instead, once its planned `style` is known to put its top `overChin` above the
	carrier's chin (AnimationCarryPoseRules.Report.overChin): `push` for a heavy item lifted past the middle of the head,
	so it would hide the eyes (`carriedTop` only estimates where the palms ride; short arms hold it higher). Nil when the
	plan stands. The planner keeps the lift unless the push passes.
]=]
function AnimationCarryHoldRules.instead(
	item: Item,
	style: Style,
	overChin: number,
	rig: AnimationTypes.CarryRig
): Style?
	if
		style == "under"
		and item.override == nil
		and item.weight >= AnimationCarryHoldRules.HEAVY_WEIGHT
		and overChin > (rig.headTop - rig.headBottom) / 2
	then
		return "push"
	end
	return nil
end

return table.freeze(AnimationCarryHoldRules)
