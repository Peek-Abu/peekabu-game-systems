--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local CharacterSelectionService = require(ServerScriptService.Services.CharacterSelectionService.CharacterSelectionServiceServer)

return function(context, characterId: string)
	local player = context.Executor
	local success, err = CharacterSelectionService.selectCharacter(player, characterId)
	if success then
		return `Selected {string.upper(characterId)}! You are now playing as this character.`
	else
		return `Error: {err or "Unknown error"}`
	end
end
