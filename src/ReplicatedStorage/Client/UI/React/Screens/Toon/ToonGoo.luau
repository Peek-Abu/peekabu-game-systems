--!strict
--[=[
	ToonGoo: Gloom goo ON a component, inside its own bounds. Put it among the component's face children: a `cap` run
	pours along the top edge with drips flowing down over the face, a `pool` run sits on the floor (`bottom` px above
	the face's foot) with mounds rising. The run starts and stops clear of the rounded corners (`radius`), its pieces
	laid out by the specced ToonGooViewModel; each piece carries the kit's ink outline on its free contour and the
	lilac gloss on its lit side, so the goo reads as part of the component, never a strip hung below it or cut by a
	corner (the user's goo fixes, 2026-10-17). Presentational (exempt; story in ToonGoo.story).

	@class ToonGoo
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonGooViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonGooViewModel)

local e = React.createElement

export type ToonGooProps = {
	kind: ToonGooViewModel.Kind,
	-- The component's width (design px) and corner radius: the run keeps clear of the corners.
	width: number,
	radius: number,
	-- Optional narrower span along the edge (design px from the component's left), inside the corners.
	from: number?,
	to: number?,
	-- The run's size (1 = the kit's 128 px tiles).
	scale: number?,
	-- Cap: px below the component's top edge the goo starts (a header's foot). Pool: px above the face's foot.
	top: number?,
	bottom: number?,
	zIndex: number?,
}

local function ToonGoo(props: ToonGooProps): React.ReactNode
	local inFrom, inTo = ToonGooViewModel.inset(props.width, props.radius)
	local from = math.max(inFrom, props.from or inFrom)
	local to = math.min(inTo, props.to or inTo)
	local run = ToonGooViewModel.run(props.kind, from, to, props.scale)
	local pieces: { [string]: React.ReactNode } = {}
	for index, piece in run.pieces do
		pieces[`piece{index}`] = e("ImageLabel", {
			Position = UDim2.fromOffset(piece.x, 0),
			Size = UDim2.fromOffset(piece.width, run.height),
			BackgroundTransparency = 1,
			Image = if piece.image == "ends"
				then UIAssets.toon.gooEnds
				else if props.kind == "cap" then UIAssets.toon.capTile else UIAssets.toon.poolTile,
			ImageRectOffset = piece.rectOffset,
			ImageRectSize = piece.rectSize,
			ScaleType = Enum.ScaleType.Stretch,
			-- The ends draw over the tiles at a join.
			ZIndex = if piece.image == "ends" then 2 else 1,
		})
	end
	local cap = props.kind == "cap"
	return e("Frame", {
		AnchorPoint = if cap then Vector2.new(0, 0) else Vector2.new(0, 1),
		Position = if cap then UDim2.fromOffset(0, props.top or 0) else UDim2.new(0, 0, 1, -(props.bottom or 0)),
		Size = UDim2.new(1, 0, 0, run.height),
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, pieces)
end

return ToonGoo
