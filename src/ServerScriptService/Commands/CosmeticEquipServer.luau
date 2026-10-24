--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local CosmeticService = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)

-- The change the arguments describe, or nil with the reason.
local function changeOf(kind: string, id: string, number: number?, employee: string): (CosmeticTypes.Change?, string?)
	local slotId = if id == "-" then "" else id
	if kind == "employee" then
		return { kind = "employee", id = id }, nil
	elseif kind == "skin" then
		return { kind = "skin", id = id, style = number or 1 }, nil
	elseif kind == "idle" then
		return { kind = "idle", employee = employee, id = id }, nil
	elseif kind == "emote" then
		if number == nil then
			return nil, "an emote needs a slot (1-4)"
		end
		return { kind = "emote", employee = employee, slot = number, id = slotId }, nil
	elseif kind == "sticker" then
		if number == nil then
			return nil, "a sticker needs a slot (1-4)"
		end
		return { kind = "sticker", slot = number, id = slotId }, nil
	end
	return nil, `unknown kind "{kind}" (employee, skin, idle, emote or sticker)`
end

return function(_context, target: Player, kind: string, id: string, number: number?, employee: string?)
	local change, problem = changeOf(kind, id, number, employee or CosmeticService:currentEmployee(target.UserId))
	if change == nil then
		return `Cannot equip: {problem or "?"}.`
	end
	local ok, reason = CosmeticService:equip(target.UserId, change)
	if ok then
		return `{target.Name} now wears {kind} "{id}".`
	end
	return `Did not equip {kind} "{id}" for {target.Name}: {reason or "unknown reason"}.`
end
