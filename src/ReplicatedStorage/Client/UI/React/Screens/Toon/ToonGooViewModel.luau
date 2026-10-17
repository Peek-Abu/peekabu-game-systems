--!strict
--[=[
	ToonGooViewModel: lays a run of Gloom goo along one edge of a component, inside it. A `cap` run is poured along the
	top edge (drips flow down over the face); a `pool` run sits on the floor (mounds rise up the face). A run is a left
	end, whole tiles and a right end, placed so the goo starts at `from` and stops at `to` (design px along the
	component's edge), so a drip is never cut by the component's side and the goo never reaches a rounded corner
	(`inset`). The run's scale is solved so a whole number of tiles fits exactly (within half a tile of the requested
	scale); an edge too short for both ends shrinks the whole run. This is the fix for goo that looked cut off or hung
	below a component (2026-10-17). Pure.

	@class ToonGooViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

export type Kind = "cap" | "pool"

export type Piece = {
	-- "ends" draws a cell of the ends atlas (rectOffset / rectSize); "tile" draws a whole tile image.
	image: "ends" | "tile",
	x: number,
	width: number,
	rectOffset: Vector2?,
	rectSize: Vector2?,
}

export type Run = {
	pieces: { Piece },
	-- The scale the pieces are drawn at (1 = 128 px tiles) and the run's height at it.
	scale: number,
	height: number,
}

local GOO = UIToonConstants.GOO
-- The atlas cells are 256 px wide (2x a 128 px piece).
local CELL = 256
-- Neighbouring pieces overlap by a pixel so rounding never opens a seam.
local SEAM = 1

local ToonGooViewModel = {}

local function spec(kind: Kind): (number, number, number, number)
	if kind == "cap" then
		return GOO.capLeftStart, GOO.capRightEnd, GOO.capHeight, GOO.capRow
	end
	return GOO.poolLeftStart, GOO.poolRightEnd, GOO.poolHeight, GOO.poolRow
end

-- The span along an edge `length` px long that keeps clear of `radius` px corners.
function ToonGooViewModel.inset(length: number, radius: number): (number, number)
	return radius, length - radius
end

function ToonGooViewModel.run(kind: Kind, from: number, to: number, requestedScale: number?): Run
	local leftStart, rightEnd, height, row = spec(kind)
	local wanted = requestedScale or 1
	local span = to - from
	if span <= 0 then
		return { pieces = {}, scale = wanted, height = height * wanted }
	end
	-- The shortest run is the two ends meeting: the left end's goo (tile - leftStart) plus the right end's (rightEnd).
	-- Between them go `count` whole tiles; the run's scale is then solved so it spans exactly, which keeps every
	-- piece in proportion (a tile is never squeezed or stretched on its own).
	local shortest = GOO.tile - leftStart + rightEnd
	local count = math.max(0, math.floor((span / wanted - shortest) / GOO.tile + 0.5))
	local scale = span / (shortest + count * GOO.tile)
	local tile = GOO.tile * scale
	local cellHeight = height * 2
	local leftX = from - leftStart * scale
	local pieces: { Piece } = {
		{
			image = "ends",
			x = leftX,
			width = tile + SEAM,
			rectOffset = Vector2.new(0, row),
			rectSize = Vector2.new(CELL, cellHeight),
		},
	}
	for index = 1, count do
		table.insert(pieces, { image = "tile", x = leftX + index * tile, width = tile + SEAM })
	end
	table.insert(pieces, {
		image = "ends",
		x = leftX + (count + 1) * tile,
		width = tile,
		rectOffset = Vector2.new(CELL, row),
		rectSize = Vector2.new(CELL, cellHeight),
	})
	return { pieces = pieces, scale = scale, height = height * scale }
end

return ToonGooViewModel
