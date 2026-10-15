--!strict
--[=[
	AnimationCarryContactUtils: where a carried item sits and where the carrier's palms go ON IT.

	Everything is in the carrier's HumanoidRootPart space at the rig's rest pose, measured from the real rig
	(AnimationTypes.CarryRig), so a chibi employee with 1-stud arms, a round torso and a big head gets a hold that fits
	her as well as a stock avatar does. The item is described by the box round its visible parts AND a probe of their
	real surface (AnimationTypes.CarryItem): every contact is found on that surface, never on the box. Planning on the
	box put the palms 0.23-0.38 stud off the art of every rounded or stepped item (the bags' round sides, the monitor's
	screen above its foot, the jug's round bottom, the plant's pot inside its leaves; measured live 2026-10-15).

	`plan` tries the styles AnimationCarryHoldRules chose, best first, and each style's placements in order of comfort.
	Each candidate's arms are solved in full (AnimationCarryArmUtils.solve: hinge elbows, forearm roll and wrist within
	anatomical limits) and judged by AnimationCarryPoseRules; the first that passes is the hold. When none passes the
	least-bad one is returned (fewest violations) and the validator flags it.

	- `under` (the default; the recycling-box hold): the near side against the belly, both palms up on its real
	  bottom, shoulder-width (or just outside a round torso), a little in from the near edge, the item riding on them.
	  A palm that finds no bottom there (a sack's round side, a plant's leaves past its pot) moves in until it does.
	  Low as the arms comfortably reach: about an upper arm below the shoulders, lower for a tall item, held up only as
	  far as short arms need; out past the face only when it would hit the head, and then as little as possible.
	- `hand`: hangs from the relaxed right hand by its handle (the art's `CarryHandle`, else the top of its real
	  surface), the arm down by the side, 10-30 degrees out and 8 forward, never raised to lift it; turned so its
	  longer level side runs front to back through the fist. Not offered when it would not clear the floor or the body.
	- `push`: it stands on the floor in front, its near face just off the belly, both palms flat on that face (found by
	  the probe) a little below the shoulders, elbows bent, fingers up.

	@class AnimationCarryContactUtils
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Animation = ReplicatedStorage.Shared.Features.Animation
local AnimationTypes = require(Animation.Data.AnimationTypes)
local AnimationCarryArmUtils = require(Animation.Utils.AnimationCarryArmUtils)
local AnimationCarryPoseRules = require(Animation.Rules.AnimationCarryPoseRules)
local AnimationCarrySurfaceUtils = require(Animation.Utils.AnimationCarrySurfaceUtils)

type Rig = AnimationTypes.CarryRig
type Item = AnimationTypes.CarryItem
type Hold = AnimationTypes.CarryHold
type Style = AnimationTypes.CarryStyle
type Arm = AnimationTypes.CarryArm
type Mount = AnimationTypes.CarryMount

-- Studs kept between the item and the torso front / the head / the floor.
local BODY_GAP = 0.08
local HEAD_GAP = 0.05
local FLOOR_GAP = 0.15
-- Of the arm's reach to the palm: first try to keep the elbows this bent, then never plan past REACH_USE.
local REACH_COMFORT = 0.85
local REACH_USE = 0.95
-- `under`: how far below the shoulders the palms ride, in reaches (an upper arm; lower for a tall item), the steps
-- further down tried when it does not fit, and the highest they may come (arms held out level).
local UNDER_DROP = 0.55
local UNDER_DROP_TALL = 0.75
local UNDER_DROP_LOWER = { 0, 0.12, 0.24 }
local UNDER_DROP_MIN = 0.25
-- When nothing clears the head, the depths tried from out past the face back to the belly.
local CLIP_STEPS = 8
-- How far in from the near edge the palms go, in hand lengths (at most half the item's depth).
local UNDER_INSET = 0.5
-- Cupping the lower sides instead (a sack too tall to ride on its bottom, a pot too narrow to get under): the
-- heights tried, as fractions of the item's height from its bottom (AnimationCarrySurfaceUtils.cup).
local CUP_RISES = { 0.3, 0.4, 0.2, 0.5 }
-- On a round body the palms go outside the torso's half width by each of PALM_OUTS in turn: wide first, so the arms
-- angle out round the belly, then narrower when that is out of reach; a round body has its shoulder joints at least
-- ROUND_INSIDE inside it (Pippa ~0.15; a stock R15's sit on its torso's edge).
local PALM_OUTS = { 0.3, 0.15, 0 }
-- The two palms under an item are at most this far apart in height, so it rides level.
local PAIR_LEVEL = 0.15
local ROUND_INSIDE = 0.1
-- `hand` (see the class): the relaxed arm's angles, the elbow just soft, the gap kept from the body's side and
-- the floor. A fist closes round a bar running front to back, so the item's longer level side is turned that way.
local RELAX_FORWARD = math.rad(8)
local RELAX_OUT_MIN = math.rad(10)
local RELAX_OUT_MAX = math.rad(30)
local RELAX_OUT_STEP = math.rad(2)
local RELAX_REACH = 0.97
local HANG_GAP = 0.08
local HANG_FLOOR_GAP = 0.22
local HANG_TURN = CFrame.Angles(0, math.pi / 2, 0)
-- `push`: the palms' heights below the shoulders tried (reaches), the reach used (elbows bent), the item's gap
-- off the floor (the face itself: AnimationCarrySurfaceUtils.face).
local PUSH_DROPS = { 0.3, 0.45, 0.15, 0.6 }
local PUSH_USES = { 0.8, 0.9 }
local PUSH_FLOOR_GAP = 0.03
-- Where each style's elbows bend toward, from the shoulder, for the right arm (X out): under, down and behind; a
-- hanging arm, behind; pushing, down and out.
local POLES: { [Style]: Vector3 } = {
	under = Vector3.new(0.4, -2, 1),
	hand = Vector3.new(0.3, 0, 1),
	push = Vector3.new(0.8, -1.2, 0.6),
}
-- The torso is grown by this (the uniform vest) when the elbows keep out of it.
local BODY_PAD = 0.08
-- At most this many candidates of a style are solved and judged.
local JUDGED = 40

local AnimationCarryContactUtils = {}

local function arms(rig: Rig): { [number]: Arm }
	return { [1] = rig.right, [-1] = rig.left }
end

local function round(rig: Rig, shoulderX: number): boolean
	return math.abs(shoulderX) < rig.torsoHalfWidth - ROUND_INSIDE
end

--[=[
	Whether `rig` is round-bodied: both shoulder joints inside its torso's half width (Pippa). A stock R15's shoulders
	sit on its torso's edge: false.
]=]
function AnimationCarryContactUtils.roundBody(rig: Rig): boolean
	return round(rig, rig.right.shoulder.X) and round(rig, rig.left.shoulder.X)
end

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

-- Where `side`'s palm goes across a box of `size`: in front of the shoulder, or `out` past a round torso's side;
-- always inside the item's footprint.
local function palmX(size: Vector3, rig: Rig, side: number, shoulderX: number, out: number): number
	local margin = math.min(0.15, size.X / 4)
	local wanted = if round(rig, shoulderX) then side * (rig.torsoHalfWidth + out) else shoulderX
	return math.clamp(wanted, -size.X / 2 + margin, size.X / 2 - margin)
end

type Candidate = { offset: CFrame, right: CFrame, left: CFrame?, mount: Mount }

-- `under`'s placements in order of comfort (see the class): the palms under its bottom first, then cupping its lower
-- sides; at each, elbows bent before arms stretched, low before lower, against the belly before out past the face.
local function under(item: Item, rig: Rig): { Candidate }
	local size = item.size
	local bodyZ = item.bodyZ or size.Z / 2
	local shoulderY = (rig.right.shoulder.Y + rig.left.shoulder.Y) / 2
	local reach = math.min(AnimationCarryArmUtils.reach(rig.right), AnimationCarryArmUtils.reach(rig.left))
	local hand = math.min(rig.right.handLength, rig.left.handLength)
	local tall = math.clamp((size.Y - 1) / 2, 0, 1)
	local drop = UNDER_DROP + (UNDER_DROP_TALL - UNDER_DROP) * tall
	local depth = bodyZ + size.Z / 2
	local inset = math.min(hand * UNDER_INSET, depth / 2)
	local near = rig.front - BODY_GAP
	local pastFace = math.min(near, rig.headFront - HEAD_GAP)
	-- Where the palms go on the item, best first: both found, or the set is skipped.
	local sets: { { [number]: CFrame } } = {}
	local function add(find: (side: number, arm: Arm) -> CFrame?)
		local contacts: { [number]: CFrame } = {}
		for side, arm in arms(rig) do
			local contact = find(side, arm)
			if contact == nil then
				return
			end
			contacts[side] = contact
		end
		table.insert(sets, contacts)
	end
	for _, palmInset in { inset, math.min(inset, 0.1) } do
		for _, out in PALM_OUTS do
			local right = AnimationCarrySurfaceUtils.support(
				item,
				palmX(size, rig, 1, rig.right.shoulder.X, out),
				bodyZ - palmInset
			)
			local left = AnimationCarrySurfaceUtils.support(
				item,
				palmX(size, rig, -1, rig.left.shoulder.X, out),
				bodyZ - palmInset
			)
			-- Both palms carry it level: a pair found at different heights (one under a strap, one under the base) is not.
			local last = sets[#sets]
			local repeated = last ~= nil and right ~= nil and (last[1].Position - right.Position).Magnitude < 1e-3
			if
				right ~= nil
				and left ~= nil
				and not repeated
				and math.abs(right.Position.Y - left.Position.Y) <= PAIR_LEVEL
			then
				table.insert(sets, { [1] = right, [-1] = left })
			end
		end
	end
	for _, rise in CUP_RISES do
		add(function(side: number): CFrame?
			return AnimationCarrySurfaceUtils.cup(item, side, -size.Y / 2 + size.Y * rise, bodyZ - inset)
		end)
	end
	local function attempt(contacts: { [number]: CFrame }, lower: number, nearZ: number, use: number): Candidate?
		local centreY = -math.huge
		for side, arm in arms(rig) do
			-- The palm as low as wanted, or as low as the arm reaches at that point.
			local contact = contacts[side]
			local at = contact.Position
			local centre, radius = AnimationCarryArmUtils.palmSphere(arm, contact.Rotation)
			local dx = at.X - centre.X
			local dz = nearZ - bodyZ + at.Z - centre.Z
			local level = (radius * use) ^ 2 - dx * dx - dz * dz
			if level <= 0 then
				return nil
			end
			local palmY = math.max(shoulderY - reach * (drop + lower), centre.Y - math.sqrt(level) + 1e-3)
			centreY = math.max(centreY, palmY - at.Y)
		end
		for side, contact in contacts do
			if centreY + contact.Position.Y > arms(rig)[side].shoulder.Y - reach * UNDER_DROP_MIN then
				return nil
			end
		end
		if centreY - size.Y / 2 < rig.floor + FLOOR_GAP then
			return nil
		end
		return {
			offset = CFrame.new(0, centreY, nearZ - bodyZ),
			right = contacts[1],
			left = contacts[-1],
			mount = "torso",
		}
	end
	-- The near face against the belly, then out past the face, then the depths between (the item kept out of the head
	-- by AnimationCarryPoseRules, on its real surface: a sack's tapering top may pass under the chin where its box
	-- would not).
	local depths: { number } = { near, pastFace }
	for step = 1, CLIP_STEPS - 1 do
		table.insert(depths, pastFace + (near - pastFace) * step / CLIP_STEPS)
	end
	local found: { Candidate } = {}
	for _, contacts in sets do
		for _, use in { REACH_COMFORT, REACH_USE } do
			for _, lower in UNDER_DROP_LOWER do
				for _, nearZ in depths do
					local candidate = attempt(contacts, lower, nearZ, use)
					if candidate ~= nil then
						table.insert(found, candidate)
					end
				end
			end
		end
	end
	return found
end

-- `hand`: the item hanging from the relaxed right hand by `handle` (see the class). Empty when it cannot hang clear.
local function hang(item: Item, rig: Rig): { Candidate }
	local size = item.size
	local handle = item.handle or AnimationCarrySurfaceUtils.top(item)
	local arm = rig.right
	local shoulder = arm.shoulder
	local _, length = AnimationCarryArmUtils.palmSphere(arm, CFrame.identity)
	local wristInGrip = arm.gripInHand:PointToObjectSpace(arm.wristInHand)
	local turn = if size.X > size.Z then HANG_TURN else CFrame.identity
	local held = turn:VectorToWorldSpace(handle)
	local across = math.min(size.X, size.Z) / 2
	local edge = math.max(math.abs(shoulder.X), rig.torsoHalfWidth) + HANG_GAP
	local out = RELAX_OUT_MIN
	while out <= RELAX_OUT_MAX + 1e-6 do
		-- The arm hangs along `along`, the wrist RELAX_REACH of its length out; the palm faces in, fingers down it,
		-- and the handle is in the fist (the grip).
		local along = Vector3.new(math.tan(out), -1, -math.tan(RELAX_FORWARD)).Unit
		local facing = along:Cross(Vector3.zAxis).Unit
		local rotation = CFrame.fromMatrix(Vector3.zero, facing:Cross(-along), facing, -along)
		local at = shoulder + along * length * RELAX_REACH - rotation:VectorToWorldSpace(wristInGrip)
		local centre = at - held
		if centre.X - across >= edge then
			if centre.Y - size.Y / 2 < rig.floor + HANG_FLOOR_GAP then
				return {}
			end
			return {
				{
					offset = CFrame.new(at) * turn * CFrame.new(-handle),
					right = CFrame.new(handle) * turn:Inverse() * rotation,
					mount = "rightHand",
				},
			}
		end
		out += RELAX_OUT_STEP
	end
	return {}
end

-- `push`'s placements (see the class): palm heights and widths tried in turn; at each, the item as near as the
-- elbows comfortably reach, kept off the belly, then stepped out toward past the face (the head is judged on its
-- real surface by AnimationCarryPoseRules: a round head's chin is well behind its face).
local function push(item: Item, rig: Rig): { Candidate }
	local size = item.size
	local shoulderY = (rig.right.shoulder.Y + rig.left.shoulder.Y) / 2
	local reach = math.min(AnimationCarryArmUtils.reach(rig.right), AnimationCarryArmUtils.reach(rig.left))
	local centreY = rig.floor + PUSH_FLOOR_GAP + size.Y / 2
	local margin = math.min(0.2, size.Y / 4)
	local belly = rig.front - BODY_GAP
	local pastFace = math.min(belly, rig.headFront - HEAD_GAP)
	local found: { Candidate } = {}
	for _, drop in PUSH_DROPS do
		for _, out in PALM_OUTS do
			local y = math.clamp(shoulderY - reach * drop - centreY, -size.Y / 2 + margin, size.Y / 2 - margin)
			local right = AnimationCarrySurfaceUtils.face(item, palmX(size, rig, 1, rig.right.shoulder.X, out), y, 1)
			local left = AnimationCarrySurfaceUtils.face(item, palmX(size, rig, -1, rig.left.shoulder.X, out), y, -1)
			if right == nil or left == nil or math.abs(right.Position.Y - left.Position.Y) > PAIR_LEVEL then
				continue
			end
			local contacts: { [number]: CFrame } = { [1] = right, [-1] = left }
			for _, use in PUSH_USES do
				-- As near as the arms reach at `use`: the nearer of the two palms' limits.
				local offsetZ = -math.huge
				for side, arm in arms(rig) do
					local contact = contacts[side]
					local at = contact.Position
					local centre, radius = AnimationCarryArmUtils.palmSphere(arm, contact.Rotation)
					local dx = at.X - centre.X
					local dy = centreY + at.Y - centre.Y
					local level = (radius * use) ^ 2 - dx * dx - dy * dy
					offsetZ = if level > 0 then math.max(offsetZ, centre.Z - math.sqrt(level) - at.Z) else math.huge
				end
				if offsetZ == math.huge then
					continue
				end
				for step = 0, CLIP_STEPS do
					local nearZ = belly + (pastFace - belly) * step / CLIP_STEPS
					table.insert(found, {
						offset = CFrame.new(0, centreY, math.min(offsetZ, nearZ - size.Z / 2)),
						right = right,
						left = left,
						mount = "root",
					})
					if nearZ - size.Z / 2 >= offsetZ then
						break
					end
				end
			end
		end
	end
	return found
end

-- The candidate's arms solved and judged.
local function judge(style: Style, candidate: Candidate, item: Item, rig: Rig): (Hold, AnimationCarryPoseRules.Report)
	local pole = POLES[style]
	local body = rig.body
	-- A handle is held in the fist (the grip); every other contact by the palm.
	local effector = if style == "hand" then rig.right.gripInHand else nil
	local right =
		AnimationCarryArmUtils.solve(rig.right, candidate.offset * candidate.right, pole, body, BODY_PAD, effector)
	local leftContact = candidate.left
	local left = if leftContact ~= nil
		then AnimationCarryArmUtils.solve(rig.left, candidate.offset * leftContact, pole, body, BODY_PAD)
		else nil
	local hold: Hold = {
		style = style,
		offset = candidate.offset,
		right = candidate.right,
		left = leftContact,
		rightPose = right,
		leftPose = left,
		mount = candidate.mount,
	}
	return hold, AnimationCarryPoseRules.check(rig, hold, item.probe, item.size)
end

local function valid(item: Item): boolean
	local size = item.size
	for _, value in { size.X, size.Y, size.Z } do
		if not finite(value) or value <= 0 then
			return false
		end
	end
	local handle = item.handle
	if handle ~= nil then
		if
			not finite(handle.X)
			or not finite(handle.Y)
			or not finite(handle.Z)
			or math.abs(handle.X) > size.X / 2 + 1e-3
			or math.abs(handle.Y) > size.Y / 2 + 1e-3
			or math.abs(handle.Z) > size.Z / 2 + 1e-3
		then
			return false
		end
	end
	local bodyZ = item.bodyZ
	return bodyZ == nil or (finite(bodyZ) and math.abs(bodyZ) <= size.Z / 2 + 1e-3)
end

--[=[
	Plans the hold of `item` on `rig`, trying `styles` in order (AnimationCarryHoldRules.choose): the first candidate
	whose solved pose passes AnimationCarryPoseRules, else the one with the fewest violations. Returns the hold and its
	report; nil for a malformed item or when no style has any placement at all. `trace` sees every judged candidate.
]=]
function AnimationCarryContactUtils.plan(
	item: Item,
	rig: Rig,
	styles: { Style },
	trace: ((Hold, AnimationCarryPoseRules.Report) -> ())?
): (Hold?, AnimationCarryPoseRules.Report?)
	if not valid(item) then
		return nil, nil
	end
	local best: Hold? = nil
	local bestReport: AnimationCarryPoseRules.Report? = nil
	for _, style: Style in styles do
		local candidates: { Candidate } = if style == "under"
			then under(item, rig)
			elseif style == "hand" then hang(item, rig)
			else push(item, rig)
		for index, candidate in candidates do
			if index > JUDGED then
				break
			end
			local hold, report = judge(style, candidate, item, rig)
			if trace ~= nil then
				trace(hold, report)
			end
			if report.ok then
				return hold, report
			end
			if bestReport == nil or #report.violations < #bestReport.violations then
				best, bestReport = hold, report
			end
		end
	end
	return best, bestReport
end

--[=[
	A hand's palm frame, in the hand's own space: at the middle of the palm's face, LookVector along the fingers,
	UpVector out of the palm. `fingers` points from the wrist toward the fingers (hand space) and is snapped to the
	hand's nearest axis, as is the palm. The palm is the side facing the body at rest, measured from `rest` (the
	hand's rest orientation in root space): down in a T pose (Pippa's rig), inward hanging at the sides (stock
	R15). `side` is 1 for the right hand, -1 for the left.
]=]
function AnimationCarryContactUtils.palmFrame(fingers: Vector3, rest: CFrame, side: number, handSize: Vector3): CFrame
	local function snap(vector: Vector3): Vector3
		local a = Vector3.new(math.abs(vector.X), math.abs(vector.Y), math.abs(vector.Z))
		if a.X >= a.Y and a.X >= a.Z then
			return Vector3.new(math.sign(vector.X), 0, 0)
		elseif a.Y >= a.Z then
			return Vector3.new(0, math.sign(vector.Y), 0)
		end
		return Vector3.new(0, 0, math.sign(vector.Z))
	end
	local along = snap(fingers)
	local outward = rest:VectorToWorldSpace(along):Cross(Vector3.zAxis) * side
	local normal = if outward.Magnitude > 0.5
		then snap(rest:VectorToObjectSpace(outward))
		else snap(rest:VectorToObjectSpace(-Vector3.yAxis))
	local depth = math.abs(normal.X) * handSize.X / 2
		+ math.abs(normal.Y) * handSize.Y / 2
		+ math.abs(normal.Z) * handSize.Z / 2
	return CFrame.fromMatrix(normal * depth, normal:Cross(-along), normal, -along)
end

return AnimationCarryContactUtils
