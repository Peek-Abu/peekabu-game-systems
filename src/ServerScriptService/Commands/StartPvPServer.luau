--!strict
--[=[
	Admin command to start a PvP proximity battle using each player's currently selected
	character and their existing world models.
	Usage: pvp <player1> <player2> [level]

	Both players must have already selected a character via the character select UI.

	@class StartPvPCommand
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local BattleServiceServer = require(ServerScriptService.Services.BattleService.BattleServiceServer)

return function(_context, player1: Player, player2: Player, level: number?)
	if not player1 or not player2 then
		return "Error: Both players must be specified"
	end

	if player1 == player2 then
		return "Error: Cannot battle yourself"
	end

	local session, err = BattleServiceServer:startPvPProximityBattle(player1, player2, level)

	if session then
		return `PvP battle started: {player1.Name} vs {player2.Name}!`
	else
		return `Error: {err or "Failed to start battle"}`
	end
end
