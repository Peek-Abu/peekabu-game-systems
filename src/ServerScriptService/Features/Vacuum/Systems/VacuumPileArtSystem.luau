--!strict
--[=[
	VacuumPileArtSystem: a dust pile's art (VacuumConstants.PILE_KINDS[kind].art). The pile stays the gameplay Part
	(sized, shrunk and aimed at exactly as before); the art is attached from the default kit, so every map (Office,
	School, Training) shows it, and the plain block is hidden while it shows. A place without the art keeps the plain
	block.

	The art is fitted not to the block but to a hidden host Part (HOST_NAME, a child of the pile: no collision, query or
	touch) the size of the kind's `artSize` box, standing on the block's floor: the art is built at the concept's size
	next to an employee and overhangs the gameplay block, whose footprint alone sets the vacuum's reach.

	Attachments are fixed to the size they were fitted at (ArtVisualSystem), so as the pile shrinks the host is resized
	and the art re-attached, but only once the pile has shrunk PILE_ART_STEP since the last fit: about a dozen fits over a
	whole pile, not one per channel tick. The last fitted scale is the pile's SCALE_ATTRIBUTE.

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
	-- The hidden Part the art is fitted to.
	HOST_NAME = "PileArtHost",
}

-- The pile's host, sized to `box` and standing on the pile's floor (created on first use), and whether it was created.
local function placeHost(pile: BasePart, box: Vector3): (BasePart, boolean)
	local found = pile:FindFirstChild(VacuumPileArtSystem.HOST_NAME)
	local host: BasePart
	local created = false
	if found ~= nil and found:IsA("BasePart") then
		host = found
	else
		created = true
		local part = Instance.new("Part")
		part.Name = VacuumPileArtSystem.HOST_NAME
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.Transparency = 1
		host = part
	end
	host.Size = box
	host.CFrame = pile.CFrame * CFrame.new(0, (box.Y - pile.Size.Y) / 2, 0)
	host.Parent = pile
	return host, created
end

-- Fits kind `style`'s art at `scale` to the pile's host; the visual, or nil when the place lacks it (a host made for it
-- is removed; an earlier fit stays as it was).
local function fit(
	pile: BasePart,
	style: VacuumConstants.PileStyle,
	scale: number,
	controller: ArtVisualSystem.Controller
): Model?
	local host, created = placeHost(pile, style.artSize * scale)
	local visual = controller.attach(host, "props", style.art, ArtKitRegistry.DEFAULT_KIT)
	if visual == nil then
		if created then
			host:Destroy()
		end
		return nil
	end
	pile.Transparency = 1
	return visual
end

--[=[
	Attaches pile `kind`'s art to `pile` at full size (from `art`, the shared controller by default); records it fitted
	at full scale. Returns the visual, or nil when the place has no art for it (the plain block stays).
]=]
function VacuumPileArtSystem.dress(pile: BasePart, kind: string, art: ArtVisualSystem.Controller?): Model?
	local style = VacuumConstants.PILE_KINDS[kind]
	if style == nil then
		return nil
	end
	local visual = fit(pile, style, 1, art or ArtVisualSystem)
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
	local style = VacuumConstants.PILE_KINDS[kind]
	local last = pile:GetAttribute(VacuumPileArtSystem.SCALE_ATTRIBUTE)
	if style == nil or type(last) ~= "number" or last - scale < VacuumConstants.PILE_ART_STEP - 1e-6 then
		return false
	end
	if fit(pile, style, scale, art or ArtVisualSystem) == nil then
		return false
	end
	pile:SetAttribute(VacuumPileArtSystem.SCALE_ATTRIBUTE, scale)
	return true
end

return VacuumPileArtSystem
