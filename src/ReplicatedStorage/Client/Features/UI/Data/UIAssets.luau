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

return UIAssets
