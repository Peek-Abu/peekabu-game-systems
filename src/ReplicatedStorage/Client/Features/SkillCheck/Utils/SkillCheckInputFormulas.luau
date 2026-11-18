--!strict
--[=[
	SkillCheckInputFormulas: input to the ring icon's angle (screen degrees, 0 = up, clockwise; SkillCheckAngleFormulas).
	A free mouse or a touch: the angle of the point round the ring's centre (`fromPoint`; none right on the centre). A
	mouse the camera has locked: a virtual cursor moved by each mouse delta and held within the ring's radius (`nudge`),
	so pushing sideways at the edge swings it round. A gamepad stick: the angle it points (`stick`; its y is up, unlike
	the screen's), none inside the deadzone. Pure.

	@class SkillCheckInputFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillCheckAngleFormulas = require(ReplicatedStorage.Shared.Features.SkillCheck.Utils.SkillCheckAngleFormulas)

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local SkillCheckInputFormulas = {}

--[=[
	The angle of screen point `point` round `centre`, or nil within `minDistance` px of it.
]=]
function SkillCheckInputFormulas.fromPoint(point: Vector2, centre: Vector2, minDistance: number): number?
	local offset = point - centre
	if offset.Magnitude < minDistance then
		return nil
	end
	return SkillCheckAngleFormulas.fromVector(offset)
end

--[=[
	The virtual cursor moved by `delta` (screen px, y down) and kept within `radius` of the centre. A non-finite delta
	leaves it where it was.
]=]
function SkillCheckInputFormulas.nudge(cursor: Vector2, delta: Vector2, radius: number): Vector2
	if not finite(delta.X) or not finite(delta.Y) then
		return cursor
	end
	local moved = cursor + delta
	if moved.Magnitude > radius and moved.Magnitude > 0 then
		return moved.Unit * radius
	end
	return moved
end

--[=[
	The angle a stick at `position` (x right, y up, -1 to 1) points, or nil inside `deadzone`.
]=]
function SkillCheckInputFormulas.stick(position: Vector2, deadzone: number): number?
	if position.Magnitude < deadzone then
		return nil
	end
	return SkillCheckAngleFormulas.fromVector(Vector2.new(position.X, -position.Y))
end

--[=[
	Whether screen point `point` is within `reach` px of `centre` (a touch near enough to steer the ring).
]=]
function SkillCheckInputFormulas.withinReach(point: Vector2, centre: Vector2, reach: number): boolean
	return (point - centre).Magnitude <= reach
end

return SkillCheckInputFormulas
