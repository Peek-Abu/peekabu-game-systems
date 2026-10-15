--!strict
--[=[
	AnimationCarrySurfaceSystem: rays against an item's VISIBLE surface, for AnimationCarryContactUtils to put the
	palms on what the player sees rather than on a box round it.

	The rays hit the visible parts' collision geometry (a MeshPart's comes from its `CollisionFidelity`). A cargo
	template's MeshParts must use `PreciseConvexDecomposition`: the engine's `Default` decomposition was measured up
	to 0.44 stud off the precise one on the cargo art (the monitor; 0.36 the coffee machine, 0.24 the water jug), and
	AnimationCarryHarness fails a template that does not. Art parts are non-queryable in play (ArtVisualSystem), so
	`open` makes them queryable for as long as the caller plans, and `release` puts every one back.

	@class AnimationCarrySurfaceSystem
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

export type Surface = { probe: AnimationTypes.CarryProbe, release: () -> () }

local AnimationCarrySurfaceSystem = {}

--[=[
	The parts of `target` a player sees (Transparency below 1), or all of its parts when none is visible.
]=]
function AnimationCarrySurfaceSystem.visibleParts(target: Instance): { BasePart }
	local all: { BasePart } = {}
	local visible: { BasePart } = {}
	local candidates: { Instance } = target:GetDescendants()
	table.insert(candidates, target)
	for _, candidate in candidates do
		if candidate:IsA("BasePart") then
			table.insert(all, candidate)
			if candidate.Transparency < 1 then
				table.insert(visible, candidate)
			end
		end
	end
	return if #visible > 0 then visible else all
end

--[=[
	A probe of `target`'s visible surface in the space of `box` (a world frame: the item's visible box), until
	`release` is called. Rays only hit those parts.
]=]
function AnimationCarrySurfaceSystem.open(target: Instance, box: CFrame): Surface
	local parts = AnimationCarrySurfaceSystem.visibleParts(target)
	local saved: { [BasePart]: boolean } = {}
	local filter: { Instance } = {}
	for _, part in parts do
		saved[part] = part.CanQuery
		part.CanQuery = true
		table.insert(filter, part)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = filter
	local released = false
	local function probe(from: Vector3, along: Vector3): (Vector3?, Vector3?)
		if released then
			return nil, nil
		end
		local hit = Workspace:Raycast(box:PointToWorldSpace(from), box:VectorToWorldSpace(along), params)
		if hit == nil then
			return nil, nil
		end
		return box:PointToObjectSpace(hit.Position), box:VectorToObjectSpace(hit.Normal)
	end
	return {
		probe = probe,
		release = function()
			if released then
				return
			end
			released = true
			for part, canQuery in saved do
				part.CanQuery = canQuery
			end
		end,
	}
end

return AnimationCarrySurfaceSystem
