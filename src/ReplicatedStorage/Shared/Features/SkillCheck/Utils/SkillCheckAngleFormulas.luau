--!strict
--[=[
	SkillCheckAngleFormulas: the closing ring's angle maths, shared by the server (judging a report, placing and
	narrowing the opening) and the client (drawing the opening, turning input into the icon's angle). Angles are screen
	degrees: 0 = straight up, growing clockwise (the screen's y points down), always compared the short way round so the
	0/360 seam never matters. Pure.

	@class SkillCheckAngleFormulas
]=]

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local SkillCheckAngleFormulas = {}

--[=[
	`angle` wrapped into [0, 360).
]=]
function SkillCheckAngleFormulas.normalize(angle: number): number
	local wrapped = angle % 360
	-- `%` can round a tiny negative up to exactly 360.
	return if wrapped >= 360 then 0 else wrapped
end

--[=[
	How far apart two angles are the short way round, 0 to 180.
]=]
function SkillCheckAngleFormulas.distance(a: number, b: number): number
	local apart = SkillCheckAngleFormulas.normalize(a - b)
	return if apart > 180 then 360 - apart else apart
end

--[=[
	Whether `angle` sits in the opening centred on `gap`, `width` degrees wide, with `tolerance` more degrees each side.
	A non-finite angle is never in it.
]=]
function SkillCheckAngleFormulas.inGap(angle: number, gap: number, width: number, tolerance: number): boolean
	if not finite(angle) then
		return false
	end
	return SkillCheckAngleFormulas.distance(angle, gap) <= width / 2 + tolerance
end

--[=[
	The opening's width at a pile's `progress` (0 to 1, clamped; NaN reads as 0): `start` at the beginning, narrowing
	straight to `finish` at the end.
]=]
function SkillCheckAngleFormulas.gapWidth(progress: number, start: number, finish: number): number
	local t = if progress == progress then math.clamp(progress, 0, 1) else 0
	return start + (finish - start) * t
end

--[=[
	How much of its width an opening keeps in Night Shift week `week`: 1 in week 1 (and for nil, NaN or under 1: Quick
	shift), `step` less for each week after the first (whole weeks), never below `floor`.
]=]
function SkillCheckAngleFormulas.weekScale(week: number?, step: number, floor: number): number
	local whole = if week ~= nil and week == week then math.max(1, math.floor(week)) else 1
	return math.max(1 - (whole - 1) * step, math.min(floor, 1))
end

--[=[
	The next opening's centre from a roll in [0, 1): anywhere for a player's first ring; otherwise at least `minShift`
	degrees round from the `previous` one, either way.
]=]
function SkillCheckAngleFormulas.nextGap(previous: number?, roll: number, minShift: number): number
	local r = if roll == roll then math.clamp(roll, 0, 0.999999) else 0
	if previous == nil then
		return SkillCheckAngleFormulas.normalize(r * 360)
	end
	return SkillCheckAngleFormulas.normalize(previous + minShift + r * (360 - 2 * minShift))
end

--[=[
	The angle a screen-space vector points at (x right, y down), or nil for a zero or non-finite vector.
]=]
function SkillCheckAngleFormulas.fromVector(vector: Vector2): number?
	if not finite(vector.X) or not finite(vector.Y) or vector.Magnitude < 1e-9 then
		return nil
	end
	return SkillCheckAngleFormulas.normalize(math.deg(math.atan2(vector.X, -vector.Y)))
end

--[=[
	The unit screen-space vector (x right, y down) at `angle`.
]=]
function SkillCheckAngleFormulas.toVector(angle: number): Vector2
	local radians = math.rad(angle)
	return Vector2.new(math.sin(radians), -math.cos(radians))
end

return SkillCheckAngleFormulas
