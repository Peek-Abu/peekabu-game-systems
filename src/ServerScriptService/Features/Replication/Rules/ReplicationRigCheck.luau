--!strict
--[=[
	ReplicationRigCheck: finds the rig parts that are not joined to its root. A client-built body is unanchored, so
	such a part drops off it at every spawn. Found in staging: the rig's old foot boots (left behind when the
	boots moved into the `Boots1` cosmetic) were welded only to each other, through a weld with an empty
	Part1. The server checks the template once at boot and logs what it finds; the art is the fix.

	A joint counts when it is enabled and both ends are set: WeldConstraint and JointInstance (Weld, Motor6D)
	by their parts, and any two-attachment Constraint (Rigid, BallSocket, Hinge, Rope, …: each keeps the part
	on the body) by the parts its attachments sit on, through Bones. Anchored parts cannot fall, so they are
	never reported. An Accessory saved in the template without its weld is reported as well.

	@class ReplicationRigCheck
]=]

local ReplicationRigCheck = {}

local function jointEnds(instance: Instance): (Instance?, Instance?)
	if instance:IsA("WeldConstraint") or instance:IsA("JointInstance") then
		if instance.Enabled then
			return instance.Part0, instance.Part1
		end
	elseif instance:IsA("Constraint") then
		local a0, a1 = instance.Attachment0, instance.Attachment1
		if instance.Enabled and a0 ~= nil and a1 ~= nil then
			return a0:FindFirstAncestorWhichIsA("BasePart"), a1:FindFirstAncestorWhichIsA("BasePart")
		end
	end
	return nil, nil
end

--[=[
	The unanchored parts of `model` that no chain of joints connects to `root`.
	@param model Model
	@param root BasePart
	@return { BasePart }
]=]
function ReplicationRigCheck.unattachedParts(model: Model, root: BasePart): { BasePart }
	local neighbours: { [BasePart]: { BasePart } } = {}
	local function link(a: BasePart, b: BasePart)
		local fromA = neighbours[a] or {}
		table.insert(fromA, b)
		neighbours[a] = fromA
		local fromB = neighbours[b] or {}
		table.insert(fromB, a)
		neighbours[b] = fromB
	end
	for _, descendant in model:GetDescendants() do
		local a, b = jointEnds(descendant)
		if a ~= nil and b ~= nil and a:IsA("BasePart") and b:IsA("BasePart") then
			link(a, b)
		end
	end

	local reached: { [BasePart]: boolean } = { [root] = true }
	local frontier: { BasePart } = { root }
	local current = table.remove(frontier)
	while current ~= nil do
		local adjacent = neighbours[current]
		if adjacent ~= nil then
			for _, neighbour in adjacent do
				if not reached[neighbour] then
					reached[neighbour] = true
					table.insert(frontier, neighbour)
				end
			end
		end
		current = table.remove(frontier)
	end

	local unattached: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.Anchored and not reached[descendant] then
			table.insert(unattached, descendant)
		end
	end
	return unattached
end

--[=[
	The parts' paths inside `model`, comma-separated, for a log line.
	@param model Model
	@param parts { BasePart }
	@return string
]=]
function ReplicationRigCheck.describe(model: Model, parts: { BasePart }): string
	local paths: { string } = {}
	local prefix = model:GetFullName() .. "."
	for _, p in parts do
		local path = p:GetFullName()
		if string.sub(path, 1, #prefix) == prefix then
			path = string.sub(path, #prefix + 1)
		end
		table.insert(paths, path)
	end
	return table.concat(paths, ", ")
end

return ReplicationRigCheck
