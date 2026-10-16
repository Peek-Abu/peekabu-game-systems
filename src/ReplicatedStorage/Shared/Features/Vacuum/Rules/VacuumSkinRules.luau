--!strict
--[=[
	VacuumSkinRules: which skin a player's backpack vacuum wears.

	@class VacuumSkinRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumSkinRegistry = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumSkinRegistry)

local VacuumSkinRules = {}

local function default(): VacuumSkinRegistry.SkinDef
	local skin = VacuumSkinRegistry.get(VacuumSkinRegistry.DEFAULT)
	assert(skin ~= nil, `no default vacuum skin {VacuumSkinRegistry.DEFAULT}`)
	return skin
end

--[=[
	The skin called `wanted` when there is one, else Standard Issue.
]=]
function VacuumSkinRules.select(wanted: string?): VacuumSkinRegistry.SkinDef
	if wanted ~= nil then
		local skin = VacuumSkinRegistry.get(wanted)
		if skin ~= nil then
			return skin
		end
	end
	return default()
end

--[=[
	The skin the player with `userId` wears (VacuumSkinRegistry's allowlist, MVP only), else Standard Issue.
]=]
function VacuumSkinRules.forPlayer(userId: number): VacuumSkinRegistry.SkinDef
	return VacuumSkinRules.select(VacuumSkinRegistry.skinFor(userId))
end

return VacuumSkinRules
