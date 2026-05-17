--!strict
--[=[
	Admin command to start a test battle between two players.
	Usage: startbattle <player1> <player2> <char1> <char2> [level]
	
	@class StartBattleCommand
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local Battler = require(ServerScriptService.Modules.Classes.Battler)
local BattleServiceServer = require(ServerScriptService.Services.BattleService.BattleServiceServer)
local CharacterDefinitions = require(ServerScriptService.Modules.Battle.Characters.CharacterDefinitions)

return function(_context, player1: Player, player2: Player, char1Id: string, char2Id: string, level: number?)
	if not player1 or not player2 then
		return "Error: Both players must be specified"
	end
	
	if player1 == player2 then
		return "Error: Cannot battle yourself"
	end
	
	-- Normalize to uppercase
	char1Id = string.upper(char1Id)
	char2Id = string.upper(char2Id)
	local battleLevel = level or 50
	
	-- Validate character IDs
	local allIds = CharacterDefinitions.getAllCharacterIds()
	if not CharacterDefinitions.getCharacterById(char1Id) then
		return `Error: Unknown character "{char1Id}". Available: {table.concat(allIds, ", ")}`
	end
	if not CharacterDefinitions.getCharacterById(char2Id) then
		return `Error: Unknown character "{char2Id}". Available: {table.concat(allIds, ", ")}`
	end
	
	-- Create battlers from character definitions
	local battlerData1 = CharacterDefinitions.createBattlerFromCharacter(char1Id, battleLevel, player1.UserId)
	local battler1 = Battler.new(battlerData1)
	
	local battlerData2 = CharacterDefinitions.createBattlerFromCharacter(char2Id, battleLevel, player2.UserId)
	local battler2 = Battler.new(battlerData2)
	
	-- Create and register session via BattleServiceServer
	local session = BattleServiceServer:startPvPBattle(player1, player2, battler1, battler2)
	
	if session then
		local char1 = CharacterDefinitions.getCharacterById(char1Id)
		local char2 = CharacterDefinitions.getCharacterById(char2Id)
		return `Battle started: {player1.Name} as {char1.name} vs {player2.Name} as {char2.name} (Lv{battleLevel})!`
	else
		return "Error: Failed to start battle"
	end
end
