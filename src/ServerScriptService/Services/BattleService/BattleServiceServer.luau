--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local BattleFactory = require(ServerScriptService.Modules.Battle.BattleFactory)
local CharacterDefinitions = require(ServerScriptService.Modules.Battle.Characters.CharacterDefinitions)
local CharacterModelManager = require(ServerScriptService.Modules.Battle.CharacterModelManager)
local NPCSpawner = require(ServerScriptService.Services.NPCService.NPCServiceServer)
local BattleEvents = require(ReplicatedStorage.Shared.Events.BattleEvents)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local RequestHandler = require(ServerScriptService.Modules.RequestHandler)

local log = Logger.new("BattleServiceServer")

--[=[
	Server-side battle management service.
	Thin orchestrator — delegates battler creation to BattleFactory,
	networking to BattleNetworking, and status effects to StatusEffectRegistry.
	@class BattleServiceServer
]=]
local BattleServiceServer = {}
BattleServiceServer.dependencies = {} :: { string }
BattleServiceServer.activeSessions = {} :: { [number]: any }
BattleServiceServer.pendingChallenges = {} :: { [number]: { challengerUserId: number, challengerCharacterId: string } }

function BattleServiceServer.init(self: any)
	self:_listenForActions()
	self:_listenForReactions()

	-- Wire proximity battle trigger
	NPCSpawner.onBattleTriggered(function(player, npcData)
		self:startProximityBattle(player, npcData)
	end)
	NPCSpawner.startProximityLoop()
	log:info("BattleServiceServer initialized")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- INTERNAL: PACKET LISTENERS
-- ══════════════════════════════════════════════════════════════════════════════

--- Find a player's battler in a session.
local function findPlayerBattler(session: any, userId: number): any?
	for _, ally in session.allies do
		if ally.userId == userId then return ally end
	end
	for _, enemy in session.enemies do
		if enemy.userId == userId then return enemy end
	end
	return nil
end

function BattleServiceServer:_listenForActions()
	BattleEvents.packets.SubmitAction.listen(RequestHandler.wrap({
		name = "BattleSubmitAction",
		rateLimit = { maxRequests = 10, windowSeconds = 5 },
		audit = false,
		handler = function(data, player: Player)
			local session = self.activeSessions[player.UserId]
			if not session then return end

			local playerBattler = findPlayerBattler(session, player.UserId)
			if not playerBattler then return end

			-- Validate move ownership
			local moveName = data.moveName
			if not playerBattler.moves or not table.find(playerBattler.moves, moveName) then
				log:warn(`Player {player.UserId} tried to use move "{moveName}" they don't have`)
				return
			end

			local MoveRegistry = require(ServerScriptService.Modules.Battle.MoveRegistry)
			local AttackAction = require(ServerScriptService.Modules.Battle.Actions.AttackAction)

			local move = MoveRegistry.getMove(moveName)
			if not move then return end

			local target = move.target:resolve({
				attacker = playerBattler,
				battle = session,
				choiceIndex = data.targetIndex,
			})
			if not target then return end

			session:submitAction(player.UserId, AttackAction.new(playerBattler, target, move))
		end,
	}))
end

function BattleServiceServer:_listenForReactions()
	BattleEvents.packets.SubmitReaction.listen(RequestHandler.wrap({
		name = "BattleSubmitReaction",
		rateLimit = { maxRequests = 20, windowSeconds = 5 },
		audit = false,
		handler = function(data, player: Player)
			local session = self.activeSessions[player.UserId]
			if not session then return end
			session:submitReaction(player.UserId, data.reactionType)
		end,
	}))
end

--- Shared cleanup callback for all battle types.
function BattleServiceServer:_makeCleanupCallback()
	return function(session: any, _data: any)
		-- Unregister players from active sessions
		for _, battler in session.allies do
			if battler.userId then
				self.activeSessions[battler.userId] = nil
				NPCSpawner.setPlayerCooldown(battler.userId)
			end
		end
		for _, battler in session.enemies do
			if battler.userId then self.activeSessions[battler.userId] = nil end
		end

		-- Cleanup models after animation delay
		task.delay(3, function()
			if session._proximityKeys then
				-- Restore WalkSpeed for proximity battlers before untracking
				local allBattlers = {}
				for _, b in session.allies do table.insert(allBattlers, b) end
				for _, b in session.enemies do table.insert(allBattlers, b) end
				for _, battler in allBattlers do
					local model = battler.model
					if model then
						local hum = model:FindFirstChildOfClass("Humanoid")
						if hum then hum.WalkSpeed = 16 end
					end
				end

				for _, key in session._proximityKeys do
					CharacterModelManager.untrackModel(key)
				end
				if session._npcId then
					NPCSpawner.releaseNPC(session._npcId)
				end
			else
				CharacterModelManager.despawnAll()
			end
		end)
	end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PUBLIC API: CHALLENGE FLOW
-- ══════════════════════════════════════════════════════════════════════════════

function BattleServiceServer:requestBattle(player: Player, targetPlayer: Player, characterId: string)
	if player == targetPlayer then return end
	
	characterId = string.upper(characterId)
	if not CharacterDefinitions.getCharacterById(characterId) then return end
	
	self.pendingChallenges[targetPlayer.UserId] = {
		challengerUserId = player.UserId,
		challengerCharacterId = characterId,
	}
end

function BattleServiceServer:acceptBattle(player: Player, characterId: string, level: number?)
	local challenge = self.pendingChallenges[player.UserId]
	if not challenge then return end

	local challenger = Players:GetPlayerByUserId(challenge.challengerUserId)
	self.pendingChallenges[player.UserId] = nil
	if not challenger then return end

	characterId = string.upper(characterId)
	if not CharacterDefinitions.getCharacterById(characterId) then return end

	local lvl = level or 50
	local b1 = BattleFactory.createBattler(challenge.challengerCharacterId, lvl, challenge.challengerUserId)
	local b2 = BattleFactory.createBattler(characterId, lvl, player.UserId)

	return BattleFactory.launchBattle({ b1 }, { b2 }, self.activeSessions, self:_makeCleanupCallback())
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PUBLIC API: DIRECT BATTLE START
-- ══════════════════════════════════════════════════════════════════════════════

--- Start a PvP battle directly (used by admin commands with pre-built battlers).
function BattleServiceServer:startPvPBattle(player1: Player, player2: Player, battler1: any, battler2: any)
	return BattleFactory.launchBattle({ battler1 }, { battler2 }, self.activeSessions, self:_makeCleanupCallback())
end

--- Start a PvP proximity battle using each player's existing world character model.
--- Both players must have a selected character. Walks them to facing arena positions.
function BattleServiceServer:startPvPProximityBattle(player1: Player, player2: Player, level: number?)
	if self.activeSessions[player1.UserId] then
		log:warn(`{player1.Name} is already in a battle`)
		return nil, `{player1.Name} is already in a battle`
	end
	if self.activeSessions[player2.UserId] then
		log:warn(`{player2.Name} is already in a battle`)
		return nil, `{player2.Name} is already in a battle`
	end

	local CharacterSelectionService = require(ServerScriptService.Services.CharacterSelectionService.CharacterSelectionServiceServer)
	local char1Id = CharacterSelectionService.getSelectedCharacter(player1.UserId)
	local char2Id = CharacterSelectionService.getSelectedCharacter(player2.UserId)

	if not char1Id then return nil, `{player1.Name} has not selected a character` end
	if not char2Id then return nil, `{player2.Name} has not selected a character` end

	local battleLevel = level or 50
	local battler1 = BattleFactory.createBattler(char1Id, battleLevel, player1.UserId)
	local battler2 = BattleFactory.createBattler(char2Id, battleLevel, player2.UserId)

	local model1 = player1.Character
	local model2 = player2.Character

	-- Arena center is midpoint between both players
	local arenaCenter = CFrame.new(0, 0, 0)
	if model1 and model1.PrimaryPart and model2 and model2.PrimaryPart then
		local mid = (model1.PrimaryPart.Position + model2.PrimaryPart.Position) / 2
		arenaCenter = CFrame.new(mid)
	end

	local slot1 = arenaCenter * CFrame.new(0, 0, 20)
	local slot2 = arenaCenter * CFrame.new(0, 0, -20) * CFrame.Angles(0, math.pi, 0)

	local key1 = `proximity_player_{player1.UserId}`
	local key2 = `proximity_player_{player2.UserId}`

	if model1 then CharacterModelManager.trackExistingModel(key1, model1) end
	if model2 then CharacterModelManager.trackExistingModel(key2, model2) end

	battler1.model = model1
	battler1.modelName = model1 and model1.Name or nil
	battler2.model = model2
	battler2.modelName = model2 and model2.Name or nil

	-- Walk both players to their arena slots concurrently
	local walkDone, totalWalks = 0, 0
	local function spawnWalk(model: any, slot: CFrame)
		if not model then return end
		totalWalks += 1
		task.spawn(function()
			CharacterModelManager.walkModelTo(model, slot, 2)
			walkDone += 1
		end)
	end
	spawnWalk(model1, slot1)
	spawnWalk(model2, slot2)
	while walkDone < totalWalks do task.wait(0.1) end

	-- Stamp formation positions after walking
	if model1 and model1.PrimaryPart then battler1.formationCFrame = model1:GetPivot() end
	if model2 and model2.PrimaryPart then battler2.formationCFrame = model2:GetPivot() end

	local session = BattleFactory.launchProximityBattle(
		{ battler1 }, { battler2 },
		self.activeSessions,
		model1, model2,
		{ key1, key2 }, nil,
		self:_makeCleanupCallback()
	)

	log:info(`PvP proximity battle started: {player1.Name} ({char1Id}) vs {player2.Name} ({char2Id})`)
	return session, nil
end

--- Start a solo PvE battle against an NPC enemy (command-based).
function BattleServiceServer:startBattle(player: Player, config: any)
	local characterId = config and config.characterId or "GOKU"
	local enemyCharacterId = config and config.enemyCharacterId or "NATSU"
	local battleLevel = config and config.level or 50
	
	local playerBattler = BattleFactory.createBattler(characterId, battleLevel, player.UserId)
	local enemyBattler = BattleFactory.createBattler(enemyCharacterId, battleLevel, nil)

	return BattleFactory.launchBattle({ playerBattler }, { enemyBattler }, self.activeSessions, self:_makeCleanupCallback())
end

--- Start a proximity-triggered battle using existing models on the map.
function BattleServiceServer:startProximityBattle(player: Player, npcData: any)
	if self.activeSessions[player.UserId] then
		log:warn(`{player.Name} is already in a battle`)
		return
	end

	local CharacterSelectionService = require(ServerScriptService.Services.CharacterSelectionService.CharacterSelectionServiceServer)
	local playerCharId = CharacterSelectionService.getSelectedCharacter(player.UserId)
	if not playerCharId then
		log:warn(`{player.Name} has no character selected`)
		return
	end

	local battleLevel = npcData.level or 50
	local playerBattler = BattleFactory.createBattler(playerCharId, battleLevel, player.UserId)
	local enemyBattler = BattleFactory.createBattler(npcData.characterId, battleLevel, nil)

	-- Calculate arena center and walk positions
	local playerChar = player.Character
	local npcModel = npcData.model
	local arenaCenter = CFrame.new(0, 5, 0)
	if playerChar and playerChar.PrimaryPart and npcModel and npcModel.PrimaryPart then
		local mid = (playerChar.PrimaryPart.Position + npcModel.PrimaryPart.Position) / 2
		arenaCenter = CFrame.new(mid)
	end

	local allySlot = arenaCenter * CFrame.new(0, 0, 20)
	local enemySlot = arenaCenter * CFrame.new(0, 0, -20) * CFrame.Angles(0, math.pi, 0)

	-- Track and walk existing models
	local playerKey = `proximity_player_{player.UserId}`
	local npcKey = `proximity_npc_{npcData.characterId}_{tick()}`

	if playerChar then CharacterModelManager.trackExistingModel(playerKey, playerChar) end
	if npcModel then CharacterModelManager.trackExistingModel(npcKey, npcModel) end

	-- Store model references and names on battlers for server-side movement and client resolution
	playerBattler.model = playerChar
	playerBattler.modelName = playerChar and playerChar.Name or nil
	enemyBattler.model = npcModel
	enemyBattler.modelName = npcModel and npcModel.Name or nil

	-- Walk concurrently
	local walkDone, totalWalks = 0, 0
	local function spawnWalk(model: any, slot: CFrame)
		if not model then return end
		totalWalks += 1
		task.spawn(function()
			CharacterModelManager.walkModelTo(model, slot, 2)
			walkDone += 1
		end)
	end
	spawnWalk(playerChar, allySlot)
	spawnWalk(npcModel, enemySlot)
	while walkDone < totalWalks do task.wait(0.1) end

	-- Stamp canonical formation positions AFTER walking so walkBack targets are accurate
	if playerChar and playerChar.PrimaryPart then
		playerBattler.formationCFrame = playerChar:GetPivot()
	end
	if npcModel and npcModel.PrimaryPart then
		enemyBattler.formationCFrame = npcModel:GetPivot()
	end

	local npcId = npcModel and npcModel:GetAttribute("npcId") or nil
	local session = BattleFactory.launchProximityBattle(
		{ playerBattler }, { enemyBattler },
		self.activeSessions,
		playerChar, npcModel,
		{ playerKey, npcKey }, npcId,
		self:_makeCleanupCallback()
	)

	log:info(`Proximity battle started: {player.Name} ({playerCharId}) vs NPC ({npcData.characterId})`)
	return session
end

type BattleServiceServer = typeof(BattleServiceServer)

return BattleServiceServer :: BattleServiceServer
