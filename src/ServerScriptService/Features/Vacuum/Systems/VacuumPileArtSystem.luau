--!strict
--[=[
	VacuumPileArtSystem: a dust pile's art (VacuumConstants.PILE_KINDS[kind].art). The pile stays the gameplay Part
	(sized, shrunk and aimed at exactly as before); the art is attached to it from the default kit, so every map
	(Office, School, Training) shows it, and the plain block is hidden while it shows. A place without the art keeps the
	plain block.

	The art is fitted to the pile's Size when attached, and attachments are fixed to that size (ArtVisualSystem), so as
	the pile shrinks the art is re-attached, but only once the pile has shrunk PILE_ART_STEP since the last fit: about a
	dozen fits over a whole pile, not one per channel tick. The last fitted scale is the pile's SCALE_ATTRIBUTE.

	@class VacuumPileArtSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtKitRegistry = require(ReplicatedStorage.Shared.Features.Art.Data.ArtKitRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)

local VacuumPileArtSystem = {
	-- The scale (1 = full size) the pile's art was last fitted at.
	SCALE_ATTRIBUTE = "PileArtScale",
}

--[=[
	Attaches pile `kind`'s art to `pile` at its current Size (from `art`, the shared controller by default); records it
	fitted at full scale. Returns the visual, or nil when the place has no art for it (the plain block stays).
]=]
function VacuumPileArtSystem.dress(pile: BasePart, kind: string, art: ArtVisualSystem.Controller?): Model?
	local style = VacuumConstants.PILE_KINDS[kind]
	if style == nil then
		return nil
	end
	local controller: ArtVisualSystem.Controller = art or ArtVisualSystem
	local visual = controller.attach(pile, "props", style.art, ArtKitRegistry.DEFAULT_KIT)
	if visual ~= nil then
		pile:SetAttribute(VacuumPileArtSystem.SCALE_ATTRIBUTE, 1)
	end
	return visual
end

--[=[
	After the pile shrank to `scale` (1 = full size): re-fits its art when the pile has shrunk PILE_ART_STEP or more
	since the last fit. Whether it re-fitted (false too for a pile with no art).
]=]
function VacuumPileArtSystem.rescale(
	pile: BasePart,
	kind: string,
	scale: number,
	art: ArtVisualSystem.Controller?
): boolean
	local last = pile:GetAttribute(VacuumPileArtSystem.SCALE_ATTRIBUTE)
	if type(last) ~= "number" or last - scale < VacuumConstants.PILE_ART_STEP - 1e-6 then
		return false
	end
	if VacuumPileArtSystem.dress(pile, kind, art) == nil then
		return false
	end
	pile:SetAttribute(VacuumPileArtSystem.SCALE_ATTRIBUTE, scale)
	return true
end

return VacuumPileArtSystem
