--!strict
--[=[
	CargoHandlingRules: what handling does to cargo (Cleanup Crew spec §4). A fragile item loses a value tier per
	impact (CargoAppraisalFormulas.value); a recycling box spills into a pile; a drop is as loud as the item is heavy,
	and the water jug splashes louder than anything. M2: rattles, puddles and slipping. What fits the hotbar inventory
	is CargoInventoryRules. Pure.

	@class CargoHandlingRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryTypes = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryTypes)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

type ItemDef = CargoTypes.ItemDef

local CargoHandlingRules = {}

--[=[
	Whether a hold ending for `reason` hit the floor. Everything does except the object being destroyed while
	held. (Cargo's own stashing and banking claim the item first, so their forced drops never get here.)
]=]
function CargoHandlingRules.isImpact(reason: CarryTypes.DropReason): boolean
	return reason ~= "destroyed"
end

function CargoHandlingRules.shouldSpill(def: ItemDef, reason: CarryTypes.DropReason): boolean
	-- Setting cargo down preserves its identity; only a deliberate throw spills it.
	return def.spills and reason == "throw"
end

--[=[
	The radius (studs) a drop of this item is heard at (the M2 Noise seam).
]=]
function CargoHandlingRules.dropNoise(def: ItemDef): number
	if def.splashes then
		return CargoConstants.SPLASH_NOISE
	end
	return CargoConstants.DROP_NOISE[def.size] or 0
end

--[=[
	Whether a carried item pulses a rattle noise (M2: CargoTraitSystem, every RATTLE_INTERVAL).
]=]
function CargoHandlingRules.rattles(def: ItemDef): boolean
	return def.rattly
end

--[=[
	Whether a hold ending for `reason` leaves a slippery puddle: the jug, hitting the floor.
]=]
function CargoHandlingRules.leavesPuddle(def: ItemDef, reason: CarryTypes.DropReason): boolean
	return def.splashes and CargoHandlingRules.isImpact(reason)
end

--[=[
	Whether a player slips on a puddle: `localPoint` is their HumanoidRootPart in the puddle's object space,
	`speed` their horizontal speed. Over its footprint, within SLIP_HEIGHT above it, at SLIP_SPEED or more, and
	not within SLIP_COOLDOWN of the last slip.
]=]
function CargoHandlingRules.slips(
	localPoint: Vector3,
	size: Vector3,
	speed: number,
	now: number,
	lastSlipAt: number
): boolean
	if speed < CargoConstants.SLIP_SPEED or now - lastSlipAt < CargoConstants.SLIP_COOLDOWN then
		return false
	end
	return math.abs(localPoint.X) <= size.X / 2
		and math.abs(localPoint.Z) <= size.Z / 2
		and localPoint.Y >= -size.Y
		and localPoint.Y <= CargoConstants.SLIP_HEIGHT
end

return CargoHandlingRules
