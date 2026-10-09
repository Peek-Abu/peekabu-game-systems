--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local NpcService = require(ServerScriptService.Features.Npc.NpcServiceServer)

return function(_context, kind: string?)
	local removed = NpcService:clear(kind)
	return if kind ~= nil then `Removed {removed} "{kind}" NPC(s).` else `Removed {removed} NPC(s).`
end
