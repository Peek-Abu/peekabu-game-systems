--!strict
--[=[
	TrainingSpotlightUtils: the UI spotlight's layout. The screen goes dark except a padded hole around the one thing to
	press: `hole` pads and clamps the target's screen box, `shades` is the four dark boxes around it (top, bottom, left,
	right; together with the hole they cover the screen exactly once), and `lineAt` places the one line of words under
	the hole, or above it when there is no room below, kept on screen. `edge` places a world target's arrow: on it, or
	on the screen's edge pointing towards it.

	@class TrainingSpotlightUtils
]=]

export type Rect = {
	position: Vector2,
	size: Vector2,
}

local TrainingSpotlightUtils = {}

--[=[
	The target's box grown by `pad` on every side and clipped to the screen.
]=]
function TrainingSpotlightUtils.hole(position: Vector2, size: Vector2, screen: Vector2, pad: number): Rect
	local left = math.clamp(position.X - pad, 0, screen.X)
	local top = math.clamp(position.Y - pad, 0, screen.Y)
	local right = math.clamp(position.X + size.X + pad, left, screen.X)
	local bottom = math.clamp(position.Y + size.Y + pad, top, screen.Y)
	return { position = Vector2.new(left, top), size = Vector2.new(right - left, bottom - top) }
end

--[=[
	The four dark boxes around `hole`: full-width top and bottom bands, then left and right of the hole between them.
]=]
function TrainingSpotlightUtils.shades(hole: Rect, screen: Vector2): { Rect }
	local left = hole.position.X
	local top = hole.position.Y
	local right = left + hole.size.X
	local bottom = top + hole.size.Y
	return {
		{ position = Vector2.zero, size = Vector2.new(screen.X, top) },
		{ position = Vector2.new(0, bottom), size = Vector2.new(screen.X, screen.Y - bottom) },
		{ position = Vector2.new(0, top), size = Vector2.new(left, bottom - top) },
		{ position = Vector2.new(right, top), size = Vector2.new(screen.X - right, bottom - top) },
	}
end

--[=[
	Where the line of words (`line` in size) goes: centred on the hole, `gap` below it, or above when it would run off
	the bottom; clamped to the screen sideways.
]=]
function TrainingSpotlightUtils.lineAt(hole: Rect, screen: Vector2, line: Vector2, gap: number): Vector2
	local centre = hole.position.X + hole.size.X / 2
	local x = math.clamp(centre - line.X / 2, 0, math.max(screen.X - line.X, 0))
	local below = hole.position.Y + hole.size.Y + gap
	local y = if below + line.Y <= screen.Y then below else math.max(hole.position.Y - gap - line.Y, 0)
	return Vector2.new(x, y)
end

--[=[
	Where a world arrow goes for a target at viewport `point` (`inFront`: in front of the camera): the point itself
	when it is on screen, pointing down at it (rotation 0); otherwise on the screen's edge, `margin` in, towards it
	(a target behind the camera is mirrored, so the arrow says "turn around"), rotated to point that way (degrees,
	clockwise, as GuiObject.Rotation). The third value says whether it is on the edge.
]=]
function TrainingSpotlightUtils.edge(
	point: Vector2,
	inFront: boolean,
	screen: Vector2,
	margin: number
): (Vector2, number, boolean)
	local centre = screen / 2
	local at = if inFront then point else screen - point
	local onScreen = inFront
		and at.X >= margin
		and at.X <= screen.X - margin
		and at.Y >= margin
		and at.Y <= screen.Y - margin
	if onScreen then
		return at, 0, false
	end
	local direction = at - centre
	if direction.Magnitude < 1e-3 then
		direction = Vector2.new(0, 1)
	end
	local scaleX = if math.abs(direction.X) > 1e-6 then (centre.X - margin) / math.abs(direction.X) else math.huge
	local scaleY = if math.abs(direction.Y) > 1e-6 then (centre.Y - margin) / math.abs(direction.Y) else math.huge
	local edge = centre + direction * math.min(scaleX, scaleY)
	return edge, math.deg(math.atan2(direction.Y, direction.X)) - 90, true
end

--[=[
	Where a world arrow goes for a target off the screen, from the target in the camera's own space (`localPoint`:
	+X right, +Y up, -Z ahead): on the screen's edge, `margin` in, on the target's side, rotated to point that way.
	A target behind the camera keeps its side (left stays left), and one straight behind points down ("turn around").
	This uses the camera's space, not a viewport projection, which flips sides for points behind the camera.
]=]
function TrainingSpotlightUtils.offscreen(localPoint: Vector3, screen: Vector2, margin: number): (Vector2, number)
	local centre = screen / 2
	local direction = Vector2.new(localPoint.X, -localPoint.Y)
	if localPoint.Z > 0 then
		-- Behind: lean down (turn around) while keeping the side.
		direction = Vector2.new(direction.X, math.abs(direction.Y) + localPoint.Z * 0.25)
	end
	if direction.Magnitude < 1e-3 then
		direction = Vector2.new(0, 1)
	end
	local scaleX = if math.abs(direction.X) > 1e-6 then (centre.X - margin) / math.abs(direction.X) else math.huge
	local scaleY = if math.abs(direction.Y) > 1e-6 then (centre.Y - margin) / math.abs(direction.Y) else math.huge
	local at = centre + direction * math.min(scaleX, scaleY)
	return at, math.deg(math.atan2(direction.Y, direction.X)) - 90
end

return TrainingSpotlightUtils
