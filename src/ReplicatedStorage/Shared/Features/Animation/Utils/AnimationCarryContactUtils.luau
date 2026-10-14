--!strict
--[=[
	AnimationCarryContactUtils: where a carried item sits and where the carrier's hands go on it.

	Everything is in the carrier's HumanoidRootPart space, measured from the real rig (`Rig`), so a chibi
	employee with short arms, a round torso and a big head gets a hold that fits her as well as a stock avatar
	does. The item sits just in front of the torso at chest/belly height (under the head, or out past its face
	when it is too tall to fit under it, never into the floor), and each hand takes the first reachable contact
	on the item's real surface: its side near the body, the near vertical edge, then the near face (palm flat on
	the back of a box too wide to reach around).

	@class AnimationCarryContactUtils
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationCarryRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationCarryRegistry)

export type Layout = { offset: CFrame, right: CFrame, left: CFrame? }

--[=[
	@interface Rig
	.leftShoulder Vector3 -- shoulder joints
	.rightShoulder Vector3
	.leftReach number -- shoulder to the palm contact point, arm straight
	.rightReach number
	.front number -- the torso's front (most negative Z)
	.headFront number -- the head's front (most negative Z)
	.headBottom number -- the head's lowest point (Y)
	.floor number -- the floor under the feet (Y)
]=]
export type Rig = {
	leftShoulder: Vector3,
	rightShoulder: Vector3,
	leftReach: number,
	rightReach: number,
	front: number,
	headFront: number,
	headBottom: number,
	floor: number,
}

-- Studs kept between the item and the torso front / the head / the floor.
local BODY_GAP = 0.08
local HEAD_GAP = 0.05
local FLOOR_GAP = 0.15
-- Never plan a contact at the arm's full stretch.
local REACH_USE = 0.95

local AnimationCarryContactUtils = {}

local function valid(value: number): boolean
	return value == value and value > 0 and value < math.huge
end

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function reachable(point: CFrame, offset: CFrame, shoulder: Vector3, reach: number): boolean
	return (offset:PointToWorldSpace(point.Position) - shoulder).Magnitude <= reach * REACH_USE
end

-- The hand's -Y (its palm, where the IK end effector sits) points into the item.
local function sideTurn(side: number): CFrame
	return CFrame.Angles(0, 0, -side * math.pi / 2)
end
local FACE_TURN = CFrame.Angles(math.pi / 2, 0, 0)

-- One hand's contact on a box of `size` placed at `offset`; the near face is the box's +Z face. Nil when
-- nothing on it is reachable.
local function grip(
	size: Vector3,
	side: number,
	shoulder: Vector3,
	reach: number,
	offset: CFrame,
	gripY: number
): CFrame?
	local margin = math.min(0.2, size.X / 4)
	local inset = math.min(0.2, size.Z / 4)
	local shoulderLocal = offset:PointToObjectSpace(shoulder)
	local candidates = {
		-- On the side, just behind the near edge: wrapping the hands around it.
		CFrame.new(side * size.X / 2, gripY, size.Z / 2 - inset) * sideTurn(side),
		-- On the near vertical edge, palm angled in.
		CFrame.new(side * size.X / 2, gripY, size.Z / 2) * CFrame.Angles(0, -side * math.pi / 4, 0) * sideTurn(side),
		-- Flat on the near face, as wide as the arm allows, at the planned height then nearer the shoulder.
		CFrame.new(math.clamp(shoulderLocal.X, -size.X / 2 + margin, size.X / 2 - margin), gripY, size.Z / 2)
			* FACE_TURN,
		CFrame.new(
			math.clamp(shoulderLocal.X, -size.X / 2 + margin, size.X / 2 - margin),
			math.clamp(shoulderLocal.Y - reach * 0.3, -size.Y / 2 + margin, size.Y / 2 - margin),
			size.Z / 2
		) * FACE_TURN,
	}
	for _, candidate in candidates do
		if reachable(candidate, offset, shoulder, reach) then
			return candidate
		end
	end
	return nil
end

local function contacts(
	size: Vector3,
	rig: Rig,
	style: AnimationCarryRegistry.Style,
	offset: CFrame,
	gripY: number
): Layout?
	local right = grip(size, 1, rig.rightShoulder, rig.rightReach, offset, gripY)
	local left = grip(size, -1, rig.leftShoulder, rig.leftReach, offset, gripY)
	if right == nil then
		return nil
	end
	if left == nil and style == "twoHand" then
		return nil
	end
	return { offset = offset, right = right, left = left }
end

--[=[
	Plans the hold of an item of bounding `size` for `rig`. `requestedOffset` (a caller-owned placement, the box
	in root space) is kept as given; nil when the arms cannot reach it. Two hands always when both reach; a
	"small" or "handle" item settles for the right hand alone. Nil for a malformed size or rig.
]=]
function AnimationCarryContactUtils.plan(
	size: Vector3,
	rig: Rig,
	style: AnimationCarryRegistry.Style,
	requestedOffset: CFrame?
): Layout?
	if
		not valid(size.X)
		or not valid(size.Y)
		or not valid(size.Z)
		or not valid(rig.rightReach)
		or not valid(rig.leftReach)
		or not finite(rig.front)
		or not finite(rig.headFront)
		or not finite(rig.headBottom)
		or not finite(rig.floor)
	then
		return nil
	end
	local shoulderY = (rig.leftShoulder.Y + rig.rightShoulder.Y) / 2
	local reach = math.min(rig.leftReach, rig.rightReach)
	-- Chest/belly: half an arm below the shoulders.
	local handY = shoulderY - reach * 0.5
	local margin = math.min(0.2, size.Y / 4)
	local function gripYFor(centreY: number): number
		return math.clamp(handY - centreY, -size.Y / 2 + margin, size.Y / 2 - margin)
	end
	if requestedOffset ~= nil then
		return contacts(size, rig, style, requestedOffset, gripYFor(requestedOffset.Position.Y))
	end
	local lowest = rig.floor + FLOOR_GAP + size.Y / 2
	local underHead = rig.headBottom - HEAD_GAP - size.Y / 2
	local centreY = math.max(handY, lowest)
	local near = rig.front - BODY_GAP
	local placements: { { y: number, near: number } } = {}
	if centreY <= underHead or near <= rig.headFront - HEAD_GAP then
		table.insert(placements, { y = centreY, near = near })
	elseif underHead >= lowest then
		-- Lowered to slip under the head.
		table.insert(placements, { y = underHead, near = near })
	end
	-- Too tall for that: held out past the face.
	table.insert(placements, { y = centreY, near = math.min(near, rig.headFront - HEAD_GAP) })
	for _, placement in placements do
		local offset = CFrame.new(0, placement.y, placement.near - size.Z / 2)
		local layout = contacts(size, rig, style, offset, gripYFor(placement.y))
		if layout ~= nil then
			return layout
		end
	end
	return nil
end

--[=[
	Authored handles (`CarryGripRight` / `CarryGripLeft` on the art) replace the box contacts, but only when the
	arms reach them at the planned placement.
]=]
function AnimationCarryContactUtils.withGrips(layout: Layout, right: CFrame, left: CFrame?, rig: Rig): Layout?
	if
		not reachable(right, layout.offset, rig.rightShoulder, rig.rightReach)
		or (left ~= nil and not reachable(left, layout.offset, rig.leftShoulder, rig.leftReach))
	then
		return nil
	end
	return { offset = layout.offset, right = right, left = left }
end

return AnimationCarryContactUtils
