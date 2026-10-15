--!strict
--[=[
	AnimationCarryContactUtils: where a carried item sits and where the carrier's hands go on it.

	Everything is in the carrier's HumanoidRootPart space, measured from the real rig (`Rig`), so a chibi
	employee with short arms, a round torso and a big head gets a hold that fits her as well as a stock avatar
	does. The item is carried on the forearms: both palms up under its bottom face, shoulder-width apart (a
	narrow item brings them in under it), elbows bent down by the sides, the item resting on the hands in front
	of the belly (lower for a big item; under the head, or out past its face when it is too tall to fit under
	it, never into the floor). Reaching for the item's edges read as stiff, twisted wrists, so it is not done.
	A caller-owned placement (the bulky cart pushed ahead) keeps the old hold on the item's near side or face.
	`elbow` picks where each elbow bends so the arm stays outside the carrier's body (a small item brings the palms
	together in front of a round belly: the elbows swing out, the forearms come back in).

	@class AnimationCarryContactUtils
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationCarryRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationCarryRegistry)

-- `under`: the contacts are palm frames (`palmFrame`: LookVector along the fingers, UpVector out of the palm) on
-- the item's bottom face, palms up; otherwise the hand's end point on the item's side or face (the cart).
export type Layout = { offset: CFrame, right: CFrame, left: CFrame?, under: boolean? }
-- Hold geometry authored on the art, in box space (see `plan`).
export type Authored = { bodyZ: number? }
-- A body part the arms keep out of, as an ellipsoid in root space (`elbow`).
export type Body = { centre: Vector3, radii: Vector3 }

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
	.leftPalmReach number -- shoulder to the palm's centre (`palmFrame`), arm straight
	.rightPalmReach number
	.handLength number -- the hand along its fingers
	.torsoHalfWidth number? -- the torso's half width at rest (X); a shoulder inside it is a round body's (Pippa)
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
	leftPalmReach: number,
	rightPalmReach: number,
	handLength: number,
	torsoHalfWidth: number?,
}

-- Studs kept between the item and the torso front / the head / the floor.
local BODY_GAP = 0.08
local HEAD_GAP = 0.05
local FLOOR_GAP = 0.15
-- Never plan a contact at the arm's full stretch.
local REACH_USE = 0.95
-- How far below the shoulders the palms rest, in arm reaches: about an upper arm, so the elbows bend ~90 degrees
-- by the sides with the forearms forward. A taller item rides lower, up to UNDER_DROP_TALL; LOWER steps further
-- down when the item does not fit.
local UNDER_DROP = 0.55
local UNDER_DROP_TALL = 0.75
local UNDER_DROP_LOWER = { 0, 0.12, 0.24 }
-- First try to keep the arms this far from straight (of the palm reach), so the elbows stay bent.
local REACH_COMFORT = 0.85
-- The palms never come higher than this below the shoulders (arms held out level).
local UNDER_DROP_MIN = 0.25
-- When nothing clears the head, the item is held as far out as the arms allow: the depths tried, from out past
-- the face back to the belly, in this many steps.
local CLIP_STEPS = 8
-- How far in from the near edge the palms' centres go, in hand lengths (at most half the item's depth).
local UNDER_INSET = 0.5
-- `elbow`: the bend directions tried round the shoulder-wrist axis, and the stretches of each bone checked against
-- the body (fractions from the shoulder to the elbow, the elbow to the wrist). The upper arm's root is the shoulder
-- joint, inside the torso on a round body, and the hand rests against the item at the belly, so neither end counts.
local ELBOW_STEPS = 72
local UPPER_SPAN = { 0.5, 1 }
local FORE_SPAN = { 0, 0.7 }
local SPAN_SAMPLES = 8
-- A narrow item on a round body (shoulders inside the torso, palms pulled in under the item by more than NARROW_IN
-- from them) is held up at the chest, UNDER_DROP_NARROW below the shoulders (stepping lower when it would reach the
-- head), cupped at its edges with the fingers turned in by NARROW_YAW: the wrists then sit out toward the shoulders
-- and near enough for the arms to bend, so the elbows go out to the sides instead of the arms running straight
-- through the body to the middle (AnimationCarrySystem bends them out with `elbow`). Held at the belly, Pippa's
-- 1-stud arms are straight to reach past it and there is no bend to turn outward.
local NARROW_IN = 0.15
local UNDER_DROP_NARROW = 0.14
local NARROW_YAW = math.rad(45)
local NARROW_EDGE = 0.02
-- On a round body the palms go this far outside the torso's half width (inside the item's footprint), so the arms
-- angle out from the shoulders past the torso instead of running down through its sides.
local ROUND_OUT = 0.12
-- A round body: the shoulder joints at least this far inside the torso's half width (Pippa ~0.15; a stock R15's
-- shoulders sit on its torso's edge).
local ROUND_INSIDE = 0.1

local function round(rig: Rig, shoulderX: number): boolean
	return rig.torsoHalfWidth ~= nil and math.abs(shoulderX) < rig.torsoHalfWidth - ROUND_INSIDE
end
-- Palm up, fingers forward (-Z), rolled a little in so the wrists do not read as fully turned out.
local PALM_ROLL = math.rad(12)
local function palmUp(side: number): CFrame
	return CFrame.Angles(0, 0, side * PALM_ROLL)
end

-- Where `side`'s palm centre goes across a box of `size` (box X = root X: the box is never turned): in front of the
-- shoulder, or out past a round torso's side; always inside the item's footprint, right at its edges for a narrow
-- item on a round body (the palms cup it from below, the wrists as far out as it allows).
local function palmX(size: Vector3, rig: Rig, side: number, shoulderX: number, narrow: boolean): number
	local margin = if narrow then math.min(NARROW_EDGE, size.X / 4) else math.min(0.15, size.X / 4)
	local half = rig.torsoHalfWidth
	local wanted = if half ~= nil and round(rig, shoulderX) then side * (half + ROUND_OUT) else shoulderX
	return math.clamp(wanted, -size.X / 2 + margin, size.X / 2 - margin)
end

-- The signed unit axis nearest `vector`.
local function snap(vector: Vector3): Vector3
	local a = Vector3.new(math.abs(vector.X), math.abs(vector.Y), math.abs(vector.Z))
	if a.X >= a.Y and a.X >= a.Z then
		return Vector3.new(math.sign(vector.X), 0, 0)
	elseif a.Y >= a.Z then
		return Vector3.new(0, math.sign(vector.Y), 0)
	end
	return Vector3.new(0, 0, math.sign(vector.Z))
end

local AnimationCarryContactUtils = {}

--[=[
	Whether `rig` is round-bodied: both shoulder joints inside its torso's half width (Pippa), so its arms need the
	round-body hold and `elbow`'s bend. A stock R15's shoulders sit on its torso's edge: false.
]=]
function AnimationCarryContactUtils.roundBody(rig: Rig): boolean
	return round(rig, rig.leftShoulder.X) and round(rig, rig.rightShoulder.X)
end

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

-- The palm-up supports under a box of `size` at `offset` whose near face is at box Z `nearZ`: shoulder-width
-- apart, brought in under a narrow item, `inset` in from the near edge, fingers turned in when `narrow`. Nil when
-- an arm cannot reach.
local function supports(size: Vector3, rig: Rig, offset: CFrame, nearZ: number, inset: number, narrow: boolean): Layout?
	local hands: { [number]: CFrame } = {}
	for _, side in { 1, -1 } do
		local shoulder = if side > 0 then rig.rightShoulder else rig.leftShoulder
		local reach = if side > 0 then rig.rightPalmReach else rig.leftPalmReach
		local x = palmX(size, rig, side, offset:PointToObjectSpace(shoulder).X, narrow)
		local turn = if narrow then CFrame.Angles(0, side * NARROW_YAW, 0) else CFrame.identity
		local palm = CFrame.new(x, -size.Y / 2, nearZ - inset) * turn * palmUp(side)
		if not reachable(palm, offset, shoulder, reach) then
			return nil
		end
		hands[side] = palm
	end
	return { offset = offset, right = hands[1], left = hands[-1], under = true }
end

--[=[
	Plans the hold of an item of bounding `size` for `rig`: on the forearms, palms up under its bottom face (see
	the class). Both hands always; nil when they cannot reach it. `authored.bodyZ` (box space, from the art's
	CarryBodyFront) is the depth of the part held against the body (a pot's front, not the leaves' box): the item
	comes in that close, the palms go in from there, and it stays at the body even when it rises past the face.
	`requestedOffset` (a caller-owned placement, the box in root space: the bulky cart) is kept as given with the
	hands on its near side or face, a "small" or "handle" item settling for the right hand alone; nil when the
	arms cannot reach it. Nil for a malformed size, rig or authored value.
]=]
function AnimationCarryContactUtils.plan(
	size: Vector3,
	rig: Rig,
	style: AnimationCarryRegistry.Style,
	requestedOffset: CFrame?,
	authored: Authored?
): Layout?
	local bodyZ = if authored ~= nil and authored.bodyZ ~= nil then authored.bodyZ else size.Z / 2
	if
		not finite(bodyZ)
		or math.abs(bodyZ) > size.Z / 2 + 1e-3
		or not valid(size.X)
		or not valid(size.Y)
		or not valid(size.Z)
		or not valid(rig.rightReach)
		or not valid(rig.leftReach)
		or not valid(rig.rightPalmReach)
		or not valid(rig.leftPalmReach)
		or not valid(rig.handLength)
		or not finite(rig.front)
		or not finite(rig.headFront)
		or not finite(rig.headBottom)
		or not finite(rig.floor)
	then
		return nil
	end
	local shoulderY = (rig.leftShoulder.Y + rig.rightShoulder.Y) / 2
	local reach = math.min(rig.leftReach, rig.rightReach)
	if requestedOffset ~= nil then
		-- The cart: its old hold, hands at half an arm below the shoulders on its near side or face.
		local margin = math.min(0.2, size.Y / 4)
		local gripY =
			math.clamp(shoulderY - reach * 0.5 - requestedOffset.Position.Y, -size.Y / 2 + margin, size.Y / 2 - margin)
		return contacts(size, rig, style, requestedOffset, gripY)
	end
	local tall = math.clamp((size.Y - 1) / 2, 0, 1)
	local shoulderX = math.min(math.abs(rig.leftShoulder.X), math.abs(rig.rightShoulder.X))
	local narrow = round(rig, shoulderX) and size.X / 2 - math.min(0.15, size.X / 4) < shoulderX - NARROW_IN
	local drop = if narrow then UNDER_DROP_NARROW else UNDER_DROP + (UNDER_DROP_TALL - UNDER_DROP) * tall
	local depth = bodyZ + size.Z / 2
	local inset = math.min(rig.handLength * UNDER_INSET, depth / 2)
	local near = rig.front - BODY_GAP
	local pastFace = math.min(near, rig.headFront - HEAD_GAP)
	local function attempt(lower: number, nearZ: number, palmInset: number, anyHead: boolean, use: number): Layout?
		-- The palms' centres are on the bottom face: the item rests on them. Short arms that cannot reach that
		-- low that far out (Pippa round her belly) hold it as high as they need to, up to UNDER_DROP_MIN.
		local bottom = shoulderY - reach * (drop + lower)
		for _, side in { 1, -1 } do
			local shoulder = if side > 0 then rig.rightShoulder else rig.leftShoulder
			local palmReach = (if side > 0 then rig.rightPalmReach else rig.leftPalmReach) * use
			local x = palmX(size, rig, side, shoulder.X, narrow)
			local level = palmReach ^ 2 - (x - shoulder.X) ^ 2 - (nearZ - palmInset - shoulder.Z) ^ 2
			if level <= 0 then
				return nil
			end
			bottom = math.max(bottom, shoulder.Y - math.sqrt(level) + 1e-3)
		end
		if bottom > shoulderY - reach * (if narrow then UNDER_DROP_NARROW else UNDER_DROP_MIN) then
			return nil
		end
		local centreY = bottom + size.Y / 2
		if bottom < rig.floor + FLOOR_GAP then
			return nil
		end
		local clearsHead = centreY + size.Y / 2 <= rig.headBottom - HEAD_GAP or nearZ <= rig.headFront - HEAD_GAP
		-- An authored body front holds the item at the body even past the face (a plant's leaves).
		if not (clearsHead or anyHead or (authored ~= nil and authored.bodyZ ~= nil and nearZ == near)) then
			return nil
		end
		return supports(size, rig, CFrame.new(0, centreY, nearZ - bodyZ), bodyZ, palmInset, narrow)
	end
	-- Where the item's near face may go: against the belly, then out past the face. When neither clears the head,
	-- as far out as the arms reach, so as little of the item as possible is in the face.
	local function depths(anyHead: boolean): { number }
		if not anyHead then
			return { near, pastFace }
		end
		local list: { number } = {}
		for step = 0, CLIP_STEPS do
			table.insert(list, pastFace + (near - pastFace) * step / CLIP_STEPS)
		end
		return list
	end
	-- Elbows bent before arms stretched; against the belly, then lower, then out past the face; the palms well
	-- in under it, then barely in from the edge; and for an item too big for all of those, held as far out in
	-- front of the face as the arms allow.
	for _, anyHead in { false, true } do
		-- Past the head the arms reach as far as they safely can, the palms just in from the near edge.
		local uses: { number } = if anyHead then { REACH_USE } else { REACH_COMFORT, REACH_USE }
		-- A narrow item is cupped near its near edge too, so the wrists stay close enough to bend.
		local insets: { number } = if anyHead or narrow
			then { math.min(inset, 0.1) }
			else { inset, math.min(inset, 0.1) }
		for _, use in uses do
			for _, palmInset in insets do
				for _, lower in UNDER_DROP_LOWER do
					for _, nearZ in depths(anyHead) do
						local layout = attempt(lower, nearZ, palmInset, anyHead, use)
						if layout ~= nil then
							return layout
						end
					end
				end
			end
		end
	end
	return nil
end

-- How deep `point` is inside the bodies, each grown by `pad` (0 outside; up to 1 at a centre).
local function depthIn(point: Vector3, body: { Body }, pad: number): number
	local deepest = 0
	for _, shape in body do
		local d = ((point - shape.centre) / (shape.radii + Vector3.one * pad)).Magnitude
		deepest = math.max(deepest, 1 - d)
	end
	return deepest
end

-- How much of the arm (shoulder -> elbow -> wrist, each bone's checked stretch) is inside the body.
local function overlap(shoulder: Vector3, elbow: Vector3, wrist: Vector3, body: { Body }, pad: number): number
	local total = 0
	for k = 0, SPAN_SAMPLES do
		local t = k / SPAN_SAMPLES
		total += depthIn(shoulder:Lerp(elbow, UPPER_SPAN[1] + (UPPER_SPAN[2] - UPPER_SPAN[1]) * t), body, pad)
		total += depthIn(elbow:Lerp(wrist, FORE_SPAN[1] + (FORE_SPAN[2] - FORE_SPAN[1]) * t), body, pad)
	end
	return total
end

--[=[
	Where a two-bone arm (`upper`, `lower` long) from `shoulder` to `wrist` bends its elbow, all in root space. It
	bends toward `pole` (a direction from the shoulder, authored for the right arm: X outward; `side` 1 right, -1
	left) when that keeps the arm out of `body` (ellipsoids, grown by `pad`: worn gear); otherwise toward the bend that is
	least inside it, the nearest such to `pole`, which on a round body swings the elbow out to the side so the upper
	arm angles away from the torso and the forearm comes back in to the item. An out-of-reach wrist straightens the
	arm toward it.
]=]
function AnimationCarryContactUtils.elbow(
	shoulder: Vector3,
	wrist: Vector3,
	upper: number,
	lower: number,
	side: number,
	pole: Vector3,
	body: { Body },
	pad: number
): Vector3
	local toWrist = wrist - shoulder
	local axis = if toWrist.Magnitude > 1e-6 then toWrist.Unit else -Vector3.yAxis
	local span = math.clamp(toWrist.Magnitude, math.abs(upper - lower) + 1e-4, upper + lower - 1e-4)
	-- The elbow's circle: centred on the axis `along` from the shoulder, `radius` round it.
	local along = (upper * upper - lower * lower + span * span) / (2 * span)
	local radius = math.sqrt(math.max(0, upper * upper - along * along))
	local centre = shoulder + axis * along
	local wanted = pole * Vector3.new(side, 1, 1)
	local bend = wanted - axis * wanted:Dot(axis)
	if bend.Magnitude < 1e-6 then
		bend = Vector3.new(0, 1, 0):Cross(axis)
	end
	local u = bend.Unit
	local v = axis:Cross(u)
	local reached = shoulder + axis * span
	local function at(angle: number): (Vector3, number)
		local elbow = centre + (u * math.cos(angle) + v * math.sin(angle)) * radius
		return elbow, overlap(shoulder, elbow, reached, body, pad)
	end
	local best, bestOverlap = at(0)
	if bestOverlap <= 0 then
		return best
	end
	-- Nearest to the pole first (0, +step, -step, ...), so a tie keeps the bend closest to it.
	for k = 1, ELBOW_STEPS // 2 do
		for _, sign in { 1, -1 } do
			local elbow, inside = at(sign * k * 2 * math.pi / ELBOW_STEPS)
			if inside < bestOverlap - 1e-6 then
				best, bestOverlap = elbow, inside
			end
		end
	end
	return best
end

--[=[
	A hand's palm frame, in the hand's own space: at the middle of the palm's face, LookVector along the fingers,
	UpVector out of the palm. `fingers` points from the wrist toward the fingers (hand space) and is snapped to the
	hand's nearest axis, as is the palm. The palm is the side facing the body at rest, measured from `rest` (the
	hand's rest orientation in root space): down in a T pose (Pippa's rig), inward hanging at the sides (stock
	R15). `side` is 1 for the right hand, -1 for the left.
]=]
function AnimationCarryContactUtils.palmFrame(fingers: Vector3, rest: CFrame, side: number, handSize: Vector3): CFrame
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
