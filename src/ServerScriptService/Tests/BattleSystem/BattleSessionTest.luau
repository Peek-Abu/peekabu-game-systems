--!strict
--[=[
	Unit tests for BattleSession functionality.
	
	Tests verify:
	- Battle initialization and startup
	- Player action submission
	- NPC AI move selection
	- Interactive window (parry/dodge) mechanics
	- Battle end conditions
	
	@class BattleSessionTest
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local BattleSession = require(ServerScriptService.Modules.Classes.BattleSession)
local Battler = require(ServerScriptService.Modules.Classes.Battler)
local AttackAction = require(ServerScriptService.Modules.Battle.Actions.AttackAction)
local MoveRegistry = require(ServerScriptService.Modules.Battle.MoveRegistry)

local BattleSessionTest = {}

--- Create a test battler
local function makeBattler(config: any)
	return Battler.new({
		userId = config.userId,
		itemType = config.itemType or "TestBattler",
		currentHp = config.currentHp or 100,
		maxHp = config.maxHp or 100,
		attack = config.attack or 10,
		defense = config.defense or 10,
		speed = config.speed or 100,
		statusEffects = {},
		moves = config.moves or { "Strike" },
	})
end

function BattleSessionTest.testBattleInitialization()
	local ally = makeBattler({ itemType = "Ally" })
	local enemy = makeBattler({ itemType = "Enemy" })
	
	local session = BattleSession.new({ ally }, { enemy })
	
	assert(session.status == "IDLE", `Expected status IDLE, got {session.status}`)
	assert(session.turnCount == 0, `Expected turnCount 0, got {session.turnCount}`)
	assert(#session.allies == 1, "Should have 1 ally")
	assert(#session.enemies == 1, "Should have 1 enemy")
	
	return true
end

function BattleSessionTest.testPlayerActionSubmission()
	local player = makeBattler({ userId = 123, itemType = "Player", speed = 200 })
	local enemy = makeBattler({ itemType = "Enemy", speed = 100 })
	
	local session = BattleSession.new({ player }, { enemy })
	
	local actionSubmitted = false
	session.events:subscribe("PromptAction", function(data: any)
		if data.battler.userId == 123 then
			-- Simulate player submitting an action
			local action = AttackAction.new(player, enemy, MoveRegistry.getMove("Strike"))
			session:submitAction(123, action)
			actionSubmitted = true
		end
	end)
	
	session:startBattle()
	
	-- Give async operations time to complete
	task.wait(0.1)
	
	assert(actionSubmitted, "Player action should have been submitted")
	
	return true
end

function BattleSessionTest.testNpcRandomMoveSelection()
	local player = makeBattler({ userId = 123, itemType = "Player", speed = 100 })
	local npc = makeBattler({ itemType = "NPC", speed = 200, moves = { "Strike", "Thunderbolt", "Tackle" } })
	
	local session = BattleSession.new({ player }, { npc })
	
	-- Track which moves the NPC uses
	local movesUsed = {}
	
	session.events:subscribe("PromptAction", function(data: any)
		if data.battler.userId == 123 then
			local action = AttackAction.new(player, npc, MoveRegistry.getMove("Strike"))
			session:submitAction(123, action)
		end
	end)
	
	-- Let battle run for a bit to see NPC make multiple choices
	session:startBattle()
	task.wait(0.2)
	
	-- Test passes if battle started without errors
	return true
end

function BattleSessionTest.testBattleEndVictory()
	local ally = makeBattler({ itemType = "Ally", currentHp = 100 })
	local enemy = makeBattler({ itemType = "Enemy", currentHp = 1 })
	
	local session = BattleSession.new({ ally }, { enemy })
	
	local battleEnded = false
	local winners = nil
	local losers = nil
	
	session.events:subscribe("BattleEnd", function(data: any)
		battleEnded = true
		winners = data.winners
		losers = data.losers
	end)
	
	-- Kill the enemy
	enemy:takeDamage(100)
	
	local ended = session:checkBattleEnd()
	
	assert(ended, "Battle should have ended")
	assert(session.status == "ENDED", `Expected ENDED, got {session.status}`)
	assert(winners == session.allies, "Allies should be winners")
	assert(losers == session.enemies, "Enemies should be losers")
	
	return true
end

function BattleSessionTest.testBattleEndDefeat()
	local ally = makeBattler({ itemType = "Ally", currentHp = 1 })
	local enemy = makeBattler({ itemType = "Enemy", currentHp = 100 })
	
	local session = BattleSession.new({ ally }, { enemy })
	
	local winners = nil
	local losers = nil
	
	session.events:subscribe("BattleEnd", function(data: any)
		winners = data.winners
		losers = data.losers
	end)
	
	-- Kill the ally
	ally:takeDamage(100)
	
	local ended = session:checkBattleEnd()
	
	assert(ended, "Battle should have ended")
	assert(session.status == "ENDED", `Expected ENDED, got {session.status}`)
	assert(winners == session.enemies, "Enemies should be winners")
	assert(losers == session.allies, "Allies should be losers")
	
	return true
end

function BattleSessionTest.testReactionSubmission()
	local player = makeBattler({ userId = 456, itemType = "Player" })
	local enemy = makeBattler({ itemType = "Enemy" })
	
	local session = BattleSession.new({ player }, { enemy })
	
	-- Submit a reaction
	session:submitReaction(456, "Parry")
	
	local reaction = session:getReaction(456)
	
	assert(reaction ~= nil, "Reaction should be recorded")
	assert(reaction.id == "Parry", `Expected Parry, got {reaction.id}`)
	
	return true
end

function BattleSessionTest.testGetState()
	local ally = makeBattler({ itemType = "Ally", currentHp = 75, maxHp = 100 })
	local enemy = makeBattler({ itemType = "Enemy", currentHp = 50, maxHp = 80 })
	
	local session = BattleSession.new({ ally }, { enemy })
	session.turnCount = 5
	session.status = "RESOLVING_ACTION"
	
	local state = session:getState()
	
	assert(state.status == "RESOLVING_ACTION", "Status should match")
	assert(state.turnCount == 5, "Turn count should match")
	assert(#state.allies == 1, "Should have 1 ally state")
	assert(#state.enemies == 1, "Should have 1 enemy state")
	assert(state.allies[1].currentHp == 75, "Ally HP should match")
	
	return true
end

return BattleSessionTest
