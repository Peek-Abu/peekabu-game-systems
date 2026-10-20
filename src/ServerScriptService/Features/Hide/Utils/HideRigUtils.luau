--!strict
--[=[
	HideRigUtils: reads a live character into the plain RigShape the placement formulas take (HideHugFormulas), so the
	server can size a hiding body, welded gear included (backpack, vest, glasses).

	- joints: every Motor6D of the character (a Tool's grip is skipped), with its C0, C1 and its parts' keys.
	- pieces: each Motor6D Part1 as a jointed body part (`base` nil), and each visible part held rigidly (a Weld,
	  WeldConstraint or RigidConstraint, followed through chains of gear) to a jointed part, as `base` = that jointed part
	  and `offset` = its place in the base's space, read from the current CFrames (animation never changes a rigid one).
	- A Tool's parts and fully transparent gear are skipped, and so is the root as a piece. Parts are keyed by name, a
	  duplicate name suffixed by its order ("SteelLeg", "SteelLeg#2"), the same in `part`, `base` and the joints.

	@class HideRigUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideTypes = require(ReplicatedStorage.Shared.Features.Hide.Data.HideTypes)

local ROOT_NAME = "HumanoidRootPart"

local HideRigUtils = {}

local function inTool(instance: Instance): boolean
	return instance:FindFirstAncestorWhichIsA("Tool") ~= nil
end

-- The parts a rigid constraint or weld joins, when both exist.
local function rigidEnds(instance: Instance): (BasePart?, BasePart?)
	if instance:IsA("Weld") or instance:IsA("WeldConstraint") then
		if instance.Enabled then
			return instance.Part0, instance.Part1
		end
	elseif instance:IsA("RigidConstraint") then
		if instance.Enabled then
			local a, b = instance.Attachment0, instance.Attachment1
			local pa = if a then a.Parent else nil
			local pb = if b then b.Parent else nil
			if pa and pb and pa:IsA("BasePart") and pb:IsA("BasePart") then
				return pa, pb
			end
		end
	end
	return nil, nil
end

--[=[
	The character as a RigShape, or nil when it has no HumanoidRootPart.
]=]
function HideRigUtils.read(character: Model): HideTypes.RigShape?
	local root = character:FindFirstChild(ROOT_NAME)
	if not root or not root:IsA("BasePart") then
		return nil
	end

	-- Keys: the root first (never suffixed), then every part in tree order.
	local keys: { [BasePart]: string } = {}
	local taken: { [string]: number } = {}
	local ordered: { BasePart } = {}
	local function key(part: BasePart)
		if keys[part] then
			return
		end
		local count = (taken[part.Name] or 0) + 1
		taken[part.Name] = count
		keys[part] = if count == 1 then part.Name else string.format("%s#%d", part.Name, count)
		table.insert(ordered, part)
	end
	key(root)
	local descendants = character:GetDescendants()
	for _, instance in descendants do
		if instance:IsA("BasePart") and not inTool(instance) then
			key(instance)
		end
	end

	local joints: { HideTypes.RigJoint } = {}
	local jointed: { [BasePart]: boolean } = { [root] = true }
	local bodyParts: { BasePart } = {}
	local adjacency: { [BasePart]: { BasePart } } = {}
	local function link(a: BasePart, b: BasePart)
		adjacency[a] = adjacency[a] or {}
		adjacency[b] = adjacency[b] or {}
		table.insert(adjacency[a], b)
		table.insert(adjacency[b], a)
	end

	for _, instance in descendants do
		if inTool(instance) then
			continue
		end
		if instance:IsA("Motor6D") then
			local part0, part1 = instance.Part0, instance.Part1
			if part0 and part1 and keys[part0] and keys[part1] then
				table.insert(joints, {
					name = instance.Name,
					part0 = keys[part0],
					part1 = keys[part1],
					c0 = instance.C0,
					c1 = instance.C1,
				})
				jointed[part0] = true
				jointed[part1] = true
				if part1 ~= root then
					table.insert(bodyParts, part1)
				end
			end
		else
			local a, b = rigidEnds(instance)
			if a and b and keys[a] and keys[b] then
				link(a, b)
			end
		end
	end

	local pieces: { HideTypes.RigPiece } = {}
	local isBody: { [BasePart]: boolean } = {}
	for _, part in bodyParts do
		if not isBody[part] then
			isBody[part] = true
			table.insert(pieces, { part = keys[part], base = nil, offset = CFrame.identity, size = part.Size })
		end
	end

	-- Rigid gear: walk out from the jointed parts along welds; each part's base is the jointed part it hangs from.
	local baseOf: { [BasePart]: BasePart } = {}
	local queue: { BasePart } = {}
	for _, part in ordered do
		if jointed[part] then
			baseOf[part] = part
			table.insert(queue, part)
		end
	end
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		local neighbours = adjacency[current]
		if neighbours ~= nil then
			for _, neighbour in neighbours do
				if not baseOf[neighbour] then
					baseOf[neighbour] = baseOf[current]
					table.insert(queue, neighbour)
				end
			end
		end
	end
	for _, part in ordered do
		local base = baseOf[part]
		if base and not jointed[part] and part.Transparency < 1 then
			table.insert(pieces, {
				part = keys[part],
				base = keys[base],
				offset = base.CFrame:ToObjectSpace(part.CFrame),
				size = part.Size,
			})
		end
	end

	return { root = keys[root], joints = joints, pieces = pieces }
end

return HideRigUtils
