--!strict
--[=[
	Admin command to morph a player into a character model.
	Usage: morph <player> <characterId>
	
	@class MorphCharacterCommand
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CharacterDefinitions = require(ServerScriptService.Modules.Battle.Characters.CharacterDefinitions)
local CharacterModelManager = require(ServerScriptService.Modules.Battle.CharacterModelManager)

return function(_context, player: Player, characterId: string)
	if not player then
		return "Error: Player must be specified"
	end
	
	if not characterId then
		local allIds = CharacterDefinitions.getAllCharacterIds()
		return `Error: Character must be specified. Available: {table.concat(allIds, ", ")}`
	end
	
	characterId = string.upper(characterId)
	
	local charDef = CharacterDefinitions.getCharacterById(characterId)
	if not charDef then
		local allIds = CharacterDefinitions.getAllCharacterIds()
		return `Error: Unknown character "{characterId}". Available: {table.concat(allIds, ", ")}`
	end
	
	local success = CharacterModelManager.morphPlayer(player, characterId)
	
	if success then
		return `Morphed {player.Name} into {charDef.name}!`
	else
		return `Error: Failed to morph {player.Name}. Model "{charDef.model}" may be missing from Assets/CharacterModels.`
	end
end
