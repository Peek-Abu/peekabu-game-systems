--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local CharacterDefinitions = require(ServerScriptService.Modules.Battle.Characters.CharacterDefinitions)
local NPCSpawner = require(ServerScriptService.Services.NPCService.NPCServiceServer)

return function(context, characterId: string, level: number?, aggroRadius: number?)
	local player = context.Executor

	characterId = string.upper(characterId)
	local charDef = CharacterDefinitions.getCharacterById(characterId)
	if not charDef then
		local allIds = CharacterDefinitions.getAllCharacterIds()
		return `Error: Unknown character "{characterId}". Available: {table.concat(allIds, ", ")}`
	end

	local character = player.Character
	if not character then
		return "Error: You must have a character in the world"
	end

	-- Spawn NPC 15 studs in front of the player
	local spawnCF = character:GetPivot() * CFrame.new(0, 0, -15)

	local model = NPCSpawner.spawnNPC({
		characterId = characterId,
		level = level or 50,
		position = spawnCF,
		aggroRadius = aggroRadius or 20,
	})

	if model then
		return `Spawned NPC {charDef.name} (Lv.{level or 50}) with aggro radius {aggroRadius or 20} studs`
	else
		return `Error: Failed to spawn NPC. Model "{charDef.model}" may be missing from Assets/CharacterModels.`
	end
end
