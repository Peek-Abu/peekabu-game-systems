--!strict
--[=[
	Admin command to manually submit a battle action (for testing without client UI).
	Usage: battleaction <player> <moveName> <targetIndex>
	
	⚠️ WARNING: This command BYPASSES server-side move validation!
	It's for testing only. Real client submissions go through BattleEvents.SubmitAction
	which validates moves against the battler's moveset.
	
	@class SubmitBattleActionCommand
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local BattleServiceServer = require(ServerScriptService.Services.BattleService.BattleServiceServer)
local AttackAction = require(ServerScriptService.Modules.Battle.Actions.AttackAction)
local MoveRegistry = require(ServerScriptService.Modules.Battle.MoveRegistry)

return function(_context, player: Player, moveName: string, targetIndex: number?)
	if not player then
		return "Error: Player must be specified"
	end
	
	local session = BattleServiceServer.activeSessions[player.UserId]
	if not session then
		return `Error: {player.Name} is not in a battle`
	end
	
	-- Find the player's battler
	local playerBattler = nil
	for _, ally in session.allies do
		if ally.userId == player.UserId then
			playerBattler = ally
			break
		end
	end
	for _, enemy in session.enemies do
		if enemy.userId == player.UserId then
			playerBattler = enemy
			break
		end
	end
	
	if not playerBattler then
		return "Error: Could not find player's battler"
	end
	
	-- Check if player has this move (warn but allow for testing)
	local hasMove = false
	if playerBattler.moves then
		for _, availableMove in playerBattler.moves do
			if availableMove == moveName then
				hasMove = true
				break
			end
		end
	end
	
	if not hasMove then
		warn(`⚠️ TESTING BYPASS: {player.Name} doesn't have "{moveName}" but command allows it`)
		warn(`   Available moves: {table.concat(playerBattler.moves or {}, ", ")}`)
		warn(`   Real clients would be REJECTED by server validation!`)
	end
	
	-- Get the move from registry
	local move = MoveRegistry.getMove(moveName)
	if not move then
		return `Error: Unknown move "{moveName}". Use MoveRegistry.getAllMoveNames() for available moves.`
	end
	
	-- Find target
	local opponentSide = if table.find(session.allies, playerBattler) then session.enemies else session.allies
	local target = nil
	
	if targetIndex and targetIndex > 0 and targetIndex <= #opponentSide then
		target = opponentSide[targetIndex]
	else
		-- Default to first alive opponent
		for _, opp in opponentSide do
			if opp:isAlive() then
				target = opp
				break
			end
		end
	end
	
	if not target then
		return "Error: No valid target found"
	end
	
	-- Create and submit action
	local action = AttackAction.new(playerBattler, target, move)
	session:submitAction(player.UserId, action)
	
	return `Submitted {moveName} targeting {target.itemType}`
end
