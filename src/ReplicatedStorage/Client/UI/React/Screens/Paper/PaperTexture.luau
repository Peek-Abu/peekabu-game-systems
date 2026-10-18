--!strict
--[=[
	PaperTexture: the tiled texture over a paper's flat colour (an ImageLabel filling its parent, ScaleType Tile at the
	texture's file size), or nothing while its slot is PENDING. Put it first inside the paper frame, under the content.
	Presentational; the choice is PaperTextureViewModel.forPaper.

	@class PaperTexture
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperTextureViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTextureViewModel)

local e = React.createElement

export type PaperTextureProps = {
	paper: Color3,
	-- The paper's corner radius in px, so the texture keeps its rounded corners (0: square).
	corner: number?,
	-- Defaults to 0: under every default-ZIndex sibling, so content can never be covered by the texture.
	zIndex: number?,
}

local function PaperTexture(props: PaperTextureProps): React.ReactNode
	local layer = PaperTextureViewModel.forPaper(props.paper)
	if layer == nil then
		return nil
	end
	local corner = props.corner or 0
	return e("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = layer.image,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(layer.tile.X, layer.tile.Y),
		ZIndex = props.zIndex or 0,
	}, {
		corner = if corner > 0 then e("UICorner", { CornerRadius = UDim.new(0, corner) }) else nil,
	})
end

return PaperTexture
