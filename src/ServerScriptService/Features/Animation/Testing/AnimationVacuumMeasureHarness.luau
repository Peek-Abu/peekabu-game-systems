--!strict
--[=[
	AnimationVacuumMeasureHarness: what the vacuum hold validator (AnimationVacuumHarness) measures on a held wand: the
	grip attachments and the hands, how far each paw's wrap point sits from its grip (and whether the grip is inside the
	paw), how deep a hand or forearm sits inside the torso, and how far out and over the floor the floor head is. Reads
	the rig only. Split out of AnimationVacuumHarness.

	@class AnimationVacuumMeasureHarness
]=]

local AnimationVacuumMeasureHarness = {}

function AnimationVacuumMeasureHarness.descendant(container: Instance, name: string): Attachment?
	local found = container:FindFirstChild(name, true)
	return if found ~= nil and found:IsA("Attachment") then found else nil
end

function AnimationVacuumMeasureHarness.handOf(model: Model, side: string): BasePart?
	local found = model:FindFirstChild(side .. "Hand")
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

-- How far the paw's wrap point (hand space) is from the grip on the wand, and whether the grip is inside the paw.
function AnimationVacuumMeasureHarness.onPaw(hand: BasePart?, wrap: Vector3?, grip: Attachment?): (number?, boolean)
	if hand == nil or wrap == nil or grip == nil then
		return nil, false
	end
	local inHand = hand.CFrame:PointToObjectSpace(grip.WorldPosition)
	local half = hand.Size / 2
	local inside = math.abs(inHand.X) <= half.X and math.abs(inHand.Y) <= half.Y and math.abs(inHand.Z) <= half.Z
	return (hand.CFrame:PointToWorldSpace(wrap) - grip.WorldPosition).Magnitude, inside
end

-- How deep the deepest hand or forearm point sits inside the torso (studs): each arm part's centre and the ends of
-- its long axis, against an ellipsoid filling each torso part (round bodies).
function AnimationVacuumMeasureHarness.armClip(model: Model): number
	local deepest = 0
	local torsos: { BasePart } = {}
	for _, name in { "UpperTorso", "LowerTorso" } do
		local part = model:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			table.insert(torsos, part)
		end
	end
	for _, name in { "RightHand", "RightLowerArm", "LeftHand", "LeftLowerArm" } do
		local part = model:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			local size = part.Size
			local along = if size.Y >= size.X and size.Y >= size.Z
				then Vector3.new(0, size.Y / 2, 0)
				elseif size.X >= size.Z then Vector3.new(size.X / 2, 0, 0)
				else Vector3.new(0, 0, size.Z / 2)
			for _, offset in { Vector3.zero, along, -along } do
				local point = part.CFrame:PointToWorldSpace(offset)
				for _, torso in torsos do
					local local_ = torso.CFrame:PointToObjectSpace(point)
					local half = torso.Size / 2
					local reach = (local_.X / half.X) ^ 2 + (local_.Y / half.Y) ^ 2 + (local_.Z / half.Z) ^ 2
					if reach < 1 then
						local smallest = math.min(half.X, half.Y, half.Z)
						deepest = math.max(deepest, (1 - math.sqrt(reach)) * smallest)
					end
				end
			end
		end
	end
	return deepest
end

-- How far out the floor head sits from `model`'s root, flat (studs).
function AnimationVacuumMeasureHarness.outOf(model: Model, head: BasePart?): number?
	local root = model:FindFirstChild("HumanoidRootPart")
	if head == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	local flat = root.CFrame:PointToObjectSpace(head.Position)
	return Vector2.new(flat.X, flat.Z).Magnitude
end

-- The floor head's lowest corner over the floor under `model`'s root (studs).
function AnimationVacuumMeasureHarness.clearance(model: Model, head: BasePart?): number?
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if head == nil or root == nil or not root:IsA("BasePart") or humanoid == nil then
		return nil
	end
	local floor = root.Position.Y - (root.Size.Y / 2 + humanoid.HipHeight)
	local half = head.Size / 2
	local low = math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				low = math.min(low, head.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z)).Y)
			end
		end
	end
	return low - floor
end

return AnimationVacuumMeasureHarness
