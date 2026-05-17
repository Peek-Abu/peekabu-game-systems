--!strict
--[=[
	BattleFactory - Creates battlers and launches battle sessions.
	
	Extracted from BattleServiceServer to keep the service thin.
	Handles battler creation from character definitions and session bootstrapping.
	
	@class BattleFactory
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local BattleSession = require(ServerScriptService.Modules.Classes.BattleSession)
local Battler = require(ServerScriptService.Modules.Classes.Battler)
local CharacterDefinitions = require(ServerScriptService.Modules.Battle.Characters.CharacterDefinitions)
local CharacterModelManager = require(ServerScriptService.Modules.Battle.CharacterModelManager)
local BattleNetworking = require(ServerScriptService.Modules.Battle.BattleNetworking)
local Logger = require(game:GetService("ReplicatedStorage").Shared.Modules.Logger)

local log = Logger.new("BattleFactory")

local BattleFactory = {}

-- ══════════════════════════════════════════════════════════════════════════════
-- BATTLER CREATION
-- ══════════════════════════════════════════════════════════════════════════════

--- Create a Battler from a character ID at a given level.
function BattleFactory.createBattler(characterId: string, level: number, userId: number?): any
	local data = CharacterDefinitions.createBattlerFromCharacter(string.upper(characterId), level, userId)
	return Battler.new(data)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SESSION LAUNCHING
-- ══════════════════════════════════════════════════════════════════════════════

--- Core battle launcher. Creates session, registers players, spawns models,
--- wires networking, and starts the battle.
--- `activeSessions` is mutated to track userId → session mapping.
--- `cleanupCallback` is called on BattleEnd for session/model cleanup.
function BattleFactory.launchBattle(
	allies: { any },
	enemies: { any },
	activeSessions: { [number]: any },
	cleanupCallback: ((session: any, data: any) -> ())?
): any
	local session = BattleSession.new(allies, enemies)

	-- Register all player userIds → session
	for _, battler in allies do
		if battler.userId then
			activeSessions[battler.userId] = session
		end
	end
	for _, battler in enemies do
		if battler.userId then
			activeSessions[battler.userId] = session
		end
	end

	-- Spawn character models
	local models = CharacterModelManager.spawnBattleModels(allies, enemies)
	session._battleModels = models

	-- Stamp each battler's canonical formation position so walkBack always returns
	-- to the exact spawn slot even after repeated walkTo/walkBack sequences.
	for i, battler in allies do
		local model = models.allies[i]
		if model and model.PrimaryPart then
			battler.formationCFrame = model:GetPivot()
		end
	end
	for i, battler in enemies do
		local model = models.enemies[i]
		if model and model.PrimaryPart then
			battler.formationCFrame = model:GetPivot()
		end
	end

	-- Wire up network events
	BattleNetworking.setupSessionEvents(session, activeSessions, cleanupCallback)

	session:startBattle()
	log:info("Battle launched with standard model spawning")
	return session
end

--- Launch a proximity battle that reuses existing models (no spawning).
--- `playerModel` and `npcModel` are pre-existing models on the map.
function BattleFactory.launchProximityBattle(
	allies: { any },
	enemies: { any },
	activeSessions: { [number]: any },
	playerModel: any,
	npcModel: any,
	proximityKeys: { string },
	npcId: string?,
	cleanupCallback: ((session: any, data: any) -> ())?
): any
	local session = BattleSession.new(allies, enemies)

	-- Register all player userIds → session (allies AND enemies for PvP)
	for _, battler in allies do
		if battler.userId then
			activeSessions[battler.userId] = session
		end
	end
	for _, battler in enemies do
		if battler.userId then
			activeSessions[battler.userId] = session
		end
	end

	-- Store model refs and NPC data for cleanup
	session._battleModels = { allies = { playerModel }, enemies = { npcModel } }
	session._npcId = npcId
	session._proximityKeys = proximityKeys

	-- Wire networking and start
	BattleNetworking.setupSessionEvents(session, activeSessions, cleanupCallback)

	session:startBattle()
	log:info("Proximity battle launched with existing models")
	return session
end

return BattleFactory
