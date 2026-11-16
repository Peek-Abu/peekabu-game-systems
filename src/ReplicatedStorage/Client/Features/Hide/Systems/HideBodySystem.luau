--!strict
--[=[
	HideBodySystem: the local body hidden from (or shown back to) its own peek camera while it hides, by each part's and
	decal's LocalTransparencyModifier. Remembers what it hid so showing restores exactly those, wherever they are now.
	Split out of HideServiceClient.

	@class HideBodySystem
]=]

local HideBodySystem = {}

-- What setShown(player, false) hid. Showing restores exactly these, wherever they are now: a vacuum hidden in the hand and
-- put away meanwhile (its Tool in the Backpack) is no longer in the character, and nothing else would show it again
-- (the engine's own fade skips anything inside a Tool), so it came out invisible.
local hiddenParts: { [BasePart]: true } = {}
local hiddenDecals: { [Decal]: true } = {}

-- The local body hidden from (or shown back to) its own peek camera.
function HideBodySystem.setShown(player: Player, shown: boolean)
	if shown then
		for part in hiddenParts do
			part.LocalTransparencyModifier = 0
		end
		for decal in hiddenDecals do
			decal.LocalTransparencyModifier = 0
		end
		table.clear(hiddenParts)
		table.clear(hiddenDecals)
	end
	local character = player.Character
	if character == nil then
		return
	end
	for _, piece in character:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.LocalTransparencyModifier = if shown then 0 else 1
			if not shown then
				hiddenParts[piece] = true
			end
		elseif piece:IsA("Decal") then
			piece.LocalTransparencyModifier = if shown then 0 else 1
			if not shown then
				hiddenDecals[piece] = true
			end
		end
	end
end

return HideBodySystem
