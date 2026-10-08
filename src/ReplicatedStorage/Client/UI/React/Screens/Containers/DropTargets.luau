--!strict
--[=[
	DropTargets: which registered target a dropped item landed on.

	Split out of `InventoryPanel` so the hit test itself can be specced. That is not ceremony — this test
	silently returned the WRONG target for a while (every equip cell resolved to the one below it, because
	the point being tested had been converted into a different coordinate space), and a wrong answer here
	looks exactly like a dead drag: the drop is simply declined and nothing happens.

	The coordinate space is not this module's business. It only requires that the point and the rects are
	in the SAME one — `Slot` reports pointer positions in `AbsolutePosition` space precisely so that the
	measured rects can be passed through untouched.

	@class DropTargets
]=]

--[=[
	A rect in pixels — the measured form of a target.
	@interface Rect
	.position Vector2
	.size Vector2
]=]
export type Rect = { position: Vector2, size: Vector2 }

local DropTargets = {}

--[=[
	The id of the first rect containing `point`, or nil.

	Overlapping targets are not ordered, because the equip cells do not overlap; if a surface ever needs
	them to, this is where the tie-break belongs rather than at the call site.
	@param rects { [string]: Rect } -- target id → its rect
	@param point Vector2 -- in the same space as the rects
	@return string? -- the target id, or nil for a drop on open space
]=]
function DropTargets.rectAt(rects: { [string]: Rect }, point: Vector2): string?
	for id, rect in rects do
		if
			point.X >= rect.position.X
			and point.X <= rect.position.X + rect.size.X
			and point.Y >= rect.position.Y
			and point.Y <= rect.position.Y + rect.size.Y
		then
			return id
		end
	end
	return nil
end

--[=[
	The same test against LIVE instances, measured at the moment of the call.

	Measuring here rather than accepting rects captured earlier is deliberate: a rect recorded during a
	render can be a layout pass out of date, and a drop is exactly when the truth is wanted.
	@param cells { [string]: GuiObject } -- target id → the instance occupying it
	@param point Vector2 -- in `AbsolutePosition` space
	@return string? -- the target id, or nil for a drop on open space
]=]
function DropTargets.at(cells: { [string]: GuiObject }, point: Vector2): string?
	local rects: { [string]: Rect } = {}
	for id, instance in cells do
		rects[id] = { position = instance.AbsolutePosition, size = instance.AbsoluteSize }
	end
	return DropTargets.rectAt(rects, point)
end

return DropTargets
