--!strict
--[=[
	UIAssets: the registry of image asset ids the UI references, by name.

	The single home for `rbxassetid://` literals in UI code — the CI asset-id gate bans them anywhere
	else (asset-id literals may only live under a feature's `Data/` folder). A screen names an asset
	(`UIAssets.bar.fill`), never pastes a number, so a re-skin or a re-upload is one edit here.

	Empty in the base: each game adds its own groups, frozen, e.g.

		UIAssets.bar = table.freeze({
			fill = "rbxassetid://<id>", -- the coloured fill (tinted per resource)
			frame = "rbxassetid://<id>", -- the border drawn over the fill
		})

	@class UIAssets
]=]

local UIAssets = {}

-- A tileable texture: its asset id (PENDING "" until the developer uploads it) and its size in px, the TileSize it
-- repeats at. PaperTexture draws nothing while an id is "", so every paper stays a flat colour until then.
export type Texture = { id: string, tile: Vector2 }

-- Cleanup Crew paper textures (M3b world UI; files in assets/ui/textures/). Paste each uploaded id as
-- "rbxassetid://<number>" (PaperTextureViewModel.spec checks the form).
local PAPER: { [string]: Texture } = {
	cream = table.freeze({ id = "", tile = Vector2.new(160, 160) }), -- paper-cream.png
	manila = table.freeze({ id = "", tile = Vector2.new(160, 160) }), -- paper-manila.png
	manilaDeep = table.freeze({ id = "", tile = Vector2.new(128, 128) }), -- paper-manila-deep.png
	sticky = table.freeze({ id = "", tile = Vector2.new(128, 128) }), -- paper-sticky.png
	cork = table.freeze({ id = "", tile = Vector2.new(192, 192) }), -- cork.png
	wood = table.freeze({ id = "", tile = Vector2.new(256, 128) }), -- wood.png
}
UIAssets.paper = table.freeze(PAPER)

-- The CCTV overlay's scanlines (M3 UI). PENDING and not drawn yet.
UIAssets.cctv = table.freeze({
	scanlines = "",
})

return UIAssets
