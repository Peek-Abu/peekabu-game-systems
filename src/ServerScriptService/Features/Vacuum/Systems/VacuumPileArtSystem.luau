--!strict
--[=[
	VacuumPileArtSystem: a dust pile's art (VacuumConstants.PILE_KINDS[kind].art). The pile stays the gameplay Part
	(sized, shrunk and aimed at exactly as before); the art is attached from the default kit, so every map (Office,
	School, Training) shows it, and the plain block is hidden while it shows. A place without the art keeps the plain
	block.

	The art is fitted not to the block but to a hidden host Part (VacuumConstants.PILE_ART_HOST, a child of the pile: no
	collision, query or touch) the size of the kind's `artSize` box, standing on the block's floor: the art is built at
	the concept's size next to an employee and overhangs the gameplay block, whose footprint alone sets the vacuum's
	reach.

	It is fitted once, at full size, and never re-fitted as the pile shrinks: each client shows it at the pile's size,
	gliding (VacuumPullSystem). Re-fitting it here meant a fresh clone of the art every 5% of progress, which every
	client saw as the pile jumping smaller (P1 2026-11-14, the owner: "very snappy").

	@class VacuumPileArtSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtKitRegistry = require(ReplicatedStorage.Shared.Features.Art.Data.ArtKitRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)

local VacuumPileArtSystem = {}

-- The pile's host, sized to `box` and standing on the pile's floor (created on first use), and whether it was created.
local function placeHost(pile: BasePart, box: Vector3): (BasePart, boolean)
	local found = pile:FindFirstChild(VacuumConstants.PILE_ART_HOST)
	local host: BasePart
	local created = false
	if found ~= nil and found:IsA("BasePart") then
		host = found
	else
		created = true
		local part = Instance.new("Part")
		part.Name = VacuumConstants.PILE_ART_HOST
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

-- Fits kind `style`'s art at full size to the pile's host; the visual, or nil when the place lacks it (a host made for it
-- is removed).
local function fit(pile: BasePart, style: VacuumConstants.PileStyle, controller: ArtVisualSystem.Controller): Model?
	local host, created = placeHost(pile, style.artSize)
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
	Attaches pile `kind`'s art to `pile` at full size (from `art`, the shared controller by default). Returns the
	visual, or nil when the place has no art for it (the plain block stays).
]=]
function VacuumPileArtSystem.dress(pile: BasePart, kind: string, art: ArtVisualSystem.Controller?): Model?
	local style = VacuumConstants.PILE_KINDS[kind]
	if style == nil then
		return nil
	end
	return fit(pile, style, art or ArtVisualSystem)
end

return VacuumPileArtSystem
