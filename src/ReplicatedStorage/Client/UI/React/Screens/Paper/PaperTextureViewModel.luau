--!strict
--[=[
	PaperTextureViewModel: which tiled texture a paper colour gets (M3b world UI, the approved texture pass). A paper's
	colour names its material by hex (cream, manila, manilaDeep, sticky, cork, wood); the material's UIAssets.paper
	slot gives the image and the tile size. A PENDING slot ("") gives no layer, so the paper stays its flat colour. Pure.

	@class PaperTextureViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

export type Material = "cream" | "manila" | "manilaDeep" | "sticky" | "cork" | "wood"
export type Layer = { image: string, tile: Vector2 }

local COLOR = UIPaperConstants.COLOR

local function hexOf(color: Color3): string
	return string.lower(color:ToHex())
end

local MATERIAL_BY_HEX: { [string]: Material } = {
	[hexOf(COLOR.cream)] = "cream",
	[hexOf(COLOR.manila)] = "manila",
	[hexOf(COLOR.manilaDeep)] = "manilaDeep",
	[hexOf(COLOR.sticky)] = "sticky",
	[hexOf(COLOR.cork)] = "cork",
	[hexOf(COLOR.wood)] = "wood",
}
table.freeze(MATERIAL_BY_HEX)

local PaperTextureViewModel = {}

function PaperTextureViewModel.materialOf(paper: Color3): Material?
	return MATERIAL_BY_HEX[hexOf(paper)]
end

function PaperTextureViewModel.layer(material: Material?, slots: { [string]: UIAssets.Texture }): Layer?
	-- Tested with `not` (the DepotStore note): comparing an optional singleton union against nil widens it.
	if not material then
		return nil
	end
	local slot = slots[material]
	if slot == nil or slot.id == "" then
		return nil
	end
	return { image = slot.id, tile = slot.tile }
end

-- The layer the game draws for a paper colour (UIAssets.paper).
function PaperTextureViewModel.forPaper(paper: Color3): Layer?
	return PaperTextureViewModel.layer(PaperTextureViewModel.materialOf(paper), UIAssets.paper)
end

-- PENDING ("") or an asset id of the form the developer pastes.
function PaperTextureViewModel.validId(id: string): boolean
	return id == "" or string.match(id, "^rbxassetid://%d+$") ~= nil
end

return PaperTextureViewModel
