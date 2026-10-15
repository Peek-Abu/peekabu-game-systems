--!strict
-- Real floor landings for searched cargo. Query-disabled chair proxies still reserve their space.
local Workspace = game:GetService("Workspace")
local SpawnSystem = require(script.Parent.CargoSpawnSystem)
local Registry = require(game:GetService("ReplicatedStorage").Shared.Features.Cargo.Data.CargoRegistry)
local CargoTypes = require(game:GetService("ReplicatedStorage").Shared.Features.Cargo.Data.CargoTypes)
local CarryConstants = require(game:GetService("ReplicatedStorage").Shared.Features.Carry.Data.CarryConstants)
local CarryPlacementSystem = require(game:GetService("ServerScriptService").Features.Carry.Systems.CarryPlacementSystem)
-- The sight line from the furniture to a landing runs this high over the floor, under desk tops and shelves.
local REACH_HEIGHT = 1
local Placement = {}
function Placement.findFloor(source: BasePart, size: Vector3, map: Instance): CFrame?
	local floorY = source.Position.Y - source.Size.Y / 2
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	params.RespectCanCollide = true
	local blockers: { BasePart } = {}
	for _, o in map:GetDescendants() do
		if o:IsA("BasePart") and (o.CanCollide or type(o:GetAttribute("OfficeArtKey")) == "string") then
			table.insert(blockers, o)
		end
	end
	local function free(point: Vector3): boolean
		for _, part in blockers do
			local half = part.Size / 2
			local right, up, look = part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector
			local hx = math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z
			local hy = math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z
			local hz = math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
			if
				part.Position.Y + hy > point.Y + 0.1
				and part.Position.Y - hy < point.Y + size.Y
				and math.abs(part.Position.X - point.X) < hx + size.X / 2 + 0.2
				and math.abs(part.Position.Z - point.Z) < hz + size.Z / 2 + 0.2
			then
				return false
			end
		end
		return true
	end
	local candidates: { Vector3 } = {}
	local side = source.Size.X / 2 + size.X / 2 + 0.8
	local front = source.Size.Z / 2 + size.Z / 2 + 1.8
	for _, offset in
		{
			Vector3.new(side, 0, 0),
			Vector3.new(-side, 0, 0),
			Vector3.new(side, 0, -front),
			Vector3.new(-side, 0, -front),
			Vector3.new(0, 0, front),
		}
	do
		table.insert(candidates, source.CFrame:PointToWorldSpace(offset))
	end
	for radius = 6, 12, 3 do
		for index = 0, 7 do
			local angle = index * math.pi / 4
			table.insert(
				candidates,
				source.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			)
		end
	end
	-- Searched from inside the room: each spot must be in clear sight of the furniture's own footprint, short of
	-- every wall and over the same building's floor (CarryPlacementSystem), never in the next room or outside.
	local inside = Vector3.new(source.Position.X, floorY + REACH_HEIGHT, source.Position.Z)
	local ignore = CarryPlacementSystem.ignoreFor(source)
	local margin = math.max(size.X, size.Z) / 2 + CarryConstants.WALL_MARGIN
	for _, candidate in candidates do
		local centre = Vector3.new(candidate.X, floorY, candidate.Z)
		local supported =
			CarryPlacementSystem.reaches(inside, Vector3.new(centre.X, inside.Y, centre.Z), ignore, margin)
		if supported then
			for _, offset in
				{
					Vector3.zero,
					Vector3.new(size.X / 2, 0, size.Z / 2),
					Vector3.new(-size.X / 2, 0, size.Z / 2),
					Vector3.new(size.X / 2, 0, -size.Z / 2),
					Vector3.new(-size.X / 2, 0, -size.Z / 2),
				}
			do
				local probe = centre + offset + Vector3.new(0, 8, 0)
				local hit = Workspace:Raycast(probe, Vector3.new(0, -12, 0), params)
				if hit == nil or hit.Normal.Y < 0.9 or math.abs(hit.Position.Y - floorY) > 0.25 then
					supported = false
					break
				end
			end
		end
		if supported and free(centre) then
			return CFrame.new(centre)
		end
	end
	return nil
end
function Placement.forSearch(source: BasePart, kind: string?, parent: Instance?): (CFrame?, string?)
	local def = if kind ~= nil then Registry.get(kind) else nil
	if def == nil or parent == nil then
		return nil, nil
	end
	local map = source:FindFirstAncestorOfClass("Model") or parent
	local landing = Placement.findFloor(source, def.partSize, map)
	return landing, if landing == nil then "no clear floor landing" else nil
end
function Placement.deliver(
	kind: string?,
	parent: Instance?,
	floor: CFrame?,
	spawner: SpawnSystem.CargoSpawnSystem,
	appraisal: CargoTypes.Appraisal?
): string
	local def = if kind ~= nil then Registry.get(kind) else nil
	if kind == nil or def == nil or parent == nil or floor == nil then
		return "Nothing useful in here."
	end
	spawner:spawn(kind, floor, parent, { source = "desk", appraisal = appraisal })
	return `Found: {def.name}`
end
return Placement
