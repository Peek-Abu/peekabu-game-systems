--!strict
--[=[
	OccupantAnimationUtils: Mr. Harlow's animations (Cleanup Crew spec §7 asset pipeline: "lurch walk, look-around,
	grab and throw"). `domain` turns his uploaded slots into the Animation registry's `occupant` domain, leaving
	pending ones out (the registry asserts canonical ids at require); `poses` names his NPC idle / walk / run clips,
	his own where uploaded and the base locomotion clips otherwise; `action` names a catch clip only when it is
	uploaded. Pure.

	@class OccupantAnimationUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)
local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)

-- The Npc kind's `animations` table, field for field (NpcTypes.NpcAnimations, which Shared cannot require; table
-- fields are invariant, so the shapes must match exactly). Harlow sets idle, walk and run; attack stays unset.
export type Poses = {
	idle: string?,
	walk: string?,
	run: string?,
	attack: string?,
}

local OccupantAnimationUtils = {}

function OccupantAnimationUtils.domain(
	slots: { [string]: OccupantAssets.AnimationSlot },
	pending: string
): AnimationTypes.AnimationDomain
	local domain: AnimationTypes.AnimationDomain = {}
	for id, slot in slots do
		if slot.assetId ~= pending then
			local def: AnimationTypes.AnimationDef = {
				assetId = slot.assetId,
				priority = slot.priority,
				looped = slot.looped,
				interruption = slot.interruption,
			}
			domain[id] = table.freeze(def)
		end
	end
	return table.freeze(domain)
end

function OccupantAnimationUtils.poses(has: (id: string) -> boolean): Poses
	return {
		idle = if has("harlowLook") then "harlowLook" else "idle",
		walk = if has("harlowWalk") then "harlowWalk" else "walk",
		run = if has("harlowRun") then "harlowRun" else "run",
	}
end

function OccupantAnimationUtils.action(id: string, has: (id: string) -> boolean): string?
	return if has(id) then id else nil
end

return OccupantAnimationUtils
