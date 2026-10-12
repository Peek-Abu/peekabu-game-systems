--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationCarryRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationCarryRegistry)
export type Layout = { offset: CFrame, right: CFrame, left: CFrame? }
local AnimationCarryContactUtils = {}
local function valid(value: number): boolean
	return value == value and value > 0 and value < math.huge
end
local function reachable(point: CFrame, offset: CFrame, shoulder: Vector3, reach: number): boolean
	return (offset:PointToWorldSpace(point.Position) - shoulder).Magnitude <= reach * 0.95
end
-- Contacts lie on an actual box face. Prefer a side grip; a wide object gets a
-- reachable patch on its rear face, rather than stretching the arm to its corner.
local function grip(size: Vector3, side: number, shoulder: Vector3, reach: number, offset: CFrame): CFrame?
	local sideGrip = CFrame.new(side * size.X / 2, 0, size.Z / 2 - math.min(0.15, size.Z / 4))
		* CFrame.Angles(0, 0, -side * math.pi / 2)
	if reachable(sideGrip, offset, shoulder, reach) then
		return sideGrip
	end
	local shoulderLocal = offset:PointToObjectSpace(shoulder)
	local rearGrip = CFrame.new(
		math.clamp(shoulderLocal.X, -size.X / 2, size.X / 2),
		math.clamp(shoulderLocal.Y - reach * 0.45, -size.Y / 2, size.Y / 2),
		size.Z / 2
	) * CFrame.Angles(math.pi / 2, 0, 0)
	return if reachable(rearGrip, offset, shoulder, reach) then rearGrip else nil
end
function AnimationCarryContactUtils.plan(
	size: Vector3,
	leftShoulder: Vector3,
	rightShoulder: Vector3,
	leftReach: number,
	rightReach: number,
	style: AnimationCarryRegistry.Style,
	requestedOffset: CFrame?
): Layout?
	if not valid(size.X) or not valid(size.Y) or not valid(size.Z) or not valid(rightReach) then
		return nil
	end
	local nearDistance = math.clamp(rightReach * 0.44, 0.4, 0.8)
	local offset = requestedOffset or CFrame.new(0, 0.35, -size.Z / 2 - nearDistance)
	if style == "handle" then
		local top = CFrame.new(0, size.Y / 2, math.min(size.Z / 2, size.Z * 0.3))
		if reachable(top, offset, rightShoulder, rightReach) then
			return { offset = offset, right = top, left = nil }
		end
	end
	local right = grip(size, 1, rightShoulder, rightReach, offset)
	if right == nil then
		return nil
	end
	if style == "small" or style == "handle" then
		return { offset = offset, right = right, left = nil }
	end
	if not valid(leftReach) then
		return nil
	end
	local left = grip(size, -1, leftShoulder, leftReach, offset)
	return if left ~= nil then { offset = offset, right = right, left = left } else nil
end
-- Authored handles belong to art, but their reach is still validated here.
function AnimationCarryContactUtils.withGrips(
	layout: Layout,
	right: CFrame,
	left: CFrame?,
	leftShoulder: Vector3,
	rightShoulder: Vector3,
	leftReach: number,
	rightReach: number
): Layout?
	if
		not reachable(right, layout.offset, rightShoulder, rightReach)
		or (left ~= nil and not reachable(left, layout.offset, leftShoulder, leftReach))
	then
		return nil
	end
	return { offset = layout.offset, right = right, left = left }
end
return AnimationCarryContactUtils
