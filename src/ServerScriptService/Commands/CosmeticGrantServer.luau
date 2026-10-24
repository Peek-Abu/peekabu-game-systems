--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticService = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)

return function(_context, target: Player, id: string)
	local item = CosmeticRegistry.get(id)
	if item == nil or item.kind == "sticker" then
		return `"{id}" is not a cosmetic that can be unlocked (stickers come with their pack).`
	end
	local ok, reason = CosmeticService:grant(target.UserId, id)
	if ok then
		return `Unlocked "{id}" for {target.Name}.`
	end
	return `Did not unlock "{id}" for {target.Name}: {reason or "unknown reason"}.`
end
