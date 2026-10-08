--!strict
--[=[
	DetailPlacement: where the item detail card goes, given the slot it describes.

	Pure geometry, deliberately separated from `InventoryPanel` — the panel had grown past the module
	length limit, and this is the part of it with actual rules (prefer one side, flip, clamp) rather than
	layout, so it is the part worth having a spec for.

	The card is anchored to its slot rather than parked in a fixed spot: a card that always appears in the
	same place makes you look away from what you are pointing at, and moving along a row of items gives no
	sense that the card changed at all.

	The viewport is a PARAMETER, not read from the camera here. That is what makes the flip and the clamp
	testable without a running client, and it is the only reason those rules can be trusted at all.

	@class DetailPlacement
]=]

--[=[
	A rect in pixels — structurally the same as `Slot.SlotRect`, restated so this module stays free of
	React and can be required by a spec.
	@interface Rect
	.position Vector2
	.size Vector2
]=]
export type Rect = { position: Vector2, size: Vector2 }

local DetailPlacement = {}

-- The card's width as a fraction of the viewport, straight off the authored card, and its own aspect.
-- Height follows from the two, which is why the aspect has to be known here rather than only inside the
-- card: the placement cannot centre or clamp something whose height it cannot predict.
DetailPlacement.WIDTH_SCALE = 0.0865
DetailPlacement.ASPECT = 0.69
DetailPlacement.GAP_PX = 12 -- breathing room between the slot and the card
-- The action menu (`ItemActions`) hangs off the card's RIGHT edge, at this fraction of the card's width.
-- The flip has to reserve it: measuring only the card let a card that "just fits" push the whole EQUIP /
-- DISMANTLE / FAVORITE column off-screen, where it was clipped by the edge and partly unclickable. Kept
-- in step with `ItemActions.MENU_SIZE.Width.Scale` — it is the same authored rect, named twice because
-- this module stays free of React so it can be specced.
DetailPlacement.ACTIONS_WIDTH_SCALE = 0.622

--[=[
	The card's rect for a given anchor: to the RIGHT of the slot when there is room, flipped to its left
	when there is not, and clamped so it never runs off an edge.

	Returns a SIZE as well as a position, and that is load-bearing rather than a convenience: the card
	centres itself in whatever container it is given, so a container taller than the card parks it in the
	middle of the screen and the computed `y` does nothing at all.

	Falls back to centred when nothing is anchored — no slot has been hovered or pinned yet.
	@param anchor Rect? -- the slot the card describes
	@param viewport Vector2 -- the viewport size in pixels
	@return Vector2 -- the card's top-left, in the same space as `anchor.position`
	@return Vector2 -- the card's size
]=]
function DetailPlacement.rect(anchor: Rect?, viewport: Vector2): (Vector2, Vector2)
	local width = viewport.X * DetailPlacement.WIDTH_SCALE
	local height = width / DetailPlacement.ASPECT
	local size = Vector2.new(width, height)

	if anchor == nil then
		return Vector2.new((viewport.X - width) / 2, (viewport.Y - height) / 2), size
	end

	-- Prefer the right of the slot; flip when the card — WITH its action menu — would leave the screen.
	-- The menu is reserved whether or not the card is currently pinned, so a card does not jump sideways
	-- the moment you pin it.
	local footprint = width * (1 + DetailPlacement.ACTIONS_WIDTH_SCALE)
	local x = anchor.position.X + anchor.size.X + DetailPlacement.GAP_PX
	if x + footprint > viewport.X then
		x = anchor.position.X - width - DetailPlacement.GAP_PX
	end
	-- Centre on the slot vertically, then keep the whole card on screen. The `max` in the clamp guards a
	-- viewport shorter than the card, where the two bounds cross over.
	local y = anchor.position.Y + anchor.size.Y / 2 - height / 2
	y = math.clamp(
		y,
		DetailPlacement.GAP_PX,
		math.max(DetailPlacement.GAP_PX, viewport.Y - height - DetailPlacement.GAP_PX)
	)
	return Vector2.new(math.max(x, DetailPlacement.GAP_PX), y), size
end

return DetailPlacement
