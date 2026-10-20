--!strict
--[=[
	HideHugFormulas: the owner's knee-hug hide pose as joint Transforms, the same on every client. `pose` turns
	HideConstants.HUG_POSE (degrees, XYZ, by Motor6D name) into a CFrame per joint. `extents` measures a rig in a pose,
	`freeSize` sizes a furniture's free box, `hugFrame` puts the posed body on the floor, back to the furniture. Pure.

	@class HideHugFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local HideTypes = require(ReplicatedStorage.Shared.Features.Hide.Data.HideTypes)

local HideHugFormulas = {}

--[=[
	The hug pose's Transform for each joint it moves, by Motor6D name.
]=]
function HideHugFormulas.pose(): { [string]: CFrame }
	local transforms: { [string]: CFrame } = {}
	for _, entry in HideConstants.HUG_POSE do
		local r = entry.rotation
		transforms[entry.joint] = CFrame.new(entry.offset)
			* CFrame.fromEulerAnglesXYZ(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
	end
	return transforms
end

--[=[
	The min and max, in root space, of every piece's eight corners with the rig in `pose` (Transforms by joint name). The
	root piece is left out. A joint whose part0 is never reached is skipped.
]=]
function HideHugFormulas.extents(rig: HideTypes.RigShape, pose: { [string]: CFrame }): (Vector3, Vector3)
	local world: { [string]: CFrame } = { [rig.root] = CFrame.identity }
	local pending = table.clone(rig.joints)
	local progressed = true
	while progressed and #pending > 0 do
		progressed = false
		local remaining: { HideTypes.RigJoint } = {}
		for _, joint in pending do
			local parent = world[joint.part0]
			if parent then
				world[joint.part1] = parent * joint.c0 * (pose[joint.name] or CFrame.identity) * joint.c1:Inverse()
				progressed = true
			else
				table.insert(remaining, joint)
			end
		end
		pending = remaining
	end

	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, piece in rig.pieces do
		if piece.part == rig.root then
			continue
		end
		local frame: CFrame?
		if piece.base == nil then
			frame = world[piece.part]
		else
			local base = world[piece.base]
			frame = if base then base * piece.offset else nil
		end
		if not frame then
			continue
		end
		local half = piece.size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = frame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
					low = low:Min(corner)
					high = high:Max(corner)
				end
			end
		end
	end
	return low, high
end

--[=[
	The free box's size in studs on a piece of furniture of `size`.
]=]
function HideHugFormulas.freeSize(free: HideTypes.FreeBox, size: Vector3): Vector3
	return (free.max - free.min) * size
end

--[=[
	Where the hiding root goes: in `spot`'s frame, centred across the free box, the body's lowest point (`low`, root space)
	on its floor and its back (`high.Z`) `gap` inside its back. The root keeps the spot's rotation, facing -Z.
]=]
function HideHugFormulas.hugFrame(
	spot: CFrame,
	size: Vector3,
	free: HideTypes.FreeBox,
	low: Vector3,
	high: Vector3,
	gap: number
): CFrame
	local min, max = free.min * size, free.max * size
	local x = (min.X + max.X) / 2 - (low.X + high.X) / 2
	local y = min.Y - low.Y
	local z = max.Z - gap - high.Z
	return spot * CFrame.new(x, y, z)
end

return HideHugFormulas
