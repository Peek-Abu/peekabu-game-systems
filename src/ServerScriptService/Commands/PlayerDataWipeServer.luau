--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)

-- Kicked after the wipe: other services keep state built from the old save, and leaving saves the fresh one.
local REJOIN_MESSAGE = "Your save was reset. Join again to start fresh!"

return function(_context: { Executor: Player }, target: Player)
	local ok, reason = PlayerDataService:wipe(target.UserId)
	if not ok then
		return `Nothing wiped for {target.Name}: {reason or "unknown"}.`
	end
	target:Kick(REJOIN_MESSAGE)
	return `Wiped {target.Name}'s save. They were sent out to rejoin.`
end
