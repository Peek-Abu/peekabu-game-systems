--!strict
--[=[
	BattleNetworking - Handles all network serialization and broadcasting for battles.
	
	Extracted from BattleServiceServer to keep the service thin.
	All battler serialization, session broadcasting, and event wiring lives here.
	
	@class BattleNetworking
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local BattleEvents = require(ReplicatedStorage.Shared.Events.BattleEvents)
local BattleAnimationData = require(ReplicatedStorage.Shared.Data.BattleAnimationData)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

local log = Logger.new("BattleNetworking")

local BattleNetworking = {}

-- ══════════════════════════════════════════════════════════════════════════════
-- SERIALIZATION
-- ══════════════════════════════════════════════════════════════════════════════

--- Serialize a battler for network transmission.
function BattleNetworking.serializeBattler(battler: any, isAlly: boolean)
	return {
		itemType = battler.itemType,
		characterId = battler.characterId,
		element = battler.element,
		level = battler.level,
		currentHp = battler.currentHp,
		maxHp = battler.maxHp,
		attack = battler.attack,
		defense = battler.defense,
		speed = battler.speed,
		moves = battler.moves or {},
		passiveName = battler.passive and battler.passive.name or nil,
		statusEffects = battler.statusEffects or {},
		statusDurations = battler._statusDurations or {},
		activeBuffs = battler._activeBuffs or {},
		userId = battler.userId,
		isAlly = isAlly,
		modelName = battler.modelName,
	}
end

-- ══════════════════════════════════════════════════════════════════════════════
-- BROADCASTING
-- ══════════════════════════════════════════════════════════════════════════════

--- Collect all player UserIds from a session.
function BattleNetworking.collectPlayerIds(session: any): { number }
	local ids = {}
	for _, battler in session.allies do
		if battler.userId then table.insert(ids, battler.userId) end
	end
	for _, battler in session.enemies do
		if battler.userId then table.insert(ids, battler.userId) end
	end
	return ids
end

--- Send a packet to all players in a session.
function BattleNetworking.broadcastToSession(session: any, buildPacket: (player: Player) -> any?, packetSender: any)
	local ids = BattleNetworking.collectPlayerIds(session)
	for _, userId in ids do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local packet = buildPacket(player)
			if packet then
				packetSender(packet, player)
			end
		end
	end
end

--- Find a battler's 1-based index (allies first, then enemies).
function BattleNetworking.findBattlerIndex(session: any, battler: any): number
	for i, ally in session.allies do
		if ally == battler then return i end
	end
	for i, enemy in session.enemies do
		if enemy == battler then return #session.allies + i end
	end
	return 0
end

--- Find a battler's index from a specific player's perspective.
--- Matches the perspective-adjusted battler list sent via BattleStateUpdate:
--- players on the allies team see allies first; players on the enemies team see enemies first.
function BattleNetworking.findBattlerIndexForPlayer(session: any, battler: any, player: Player): number
	local onAlliesTeam = false
	for _, ally in session.allies do
		if ally.userId == player.UserId then onAlliesTeam = true; break end
	end

	if onAlliesTeam then
		return BattleNetworking.findBattlerIndex(session, battler)
	else
		-- From this player's perspective: session.enemies are their "allies" (1..#enemies),
		-- session.allies are their "enemies" (#enemies+1..)
		for i, enemy in session.enemies do
			if enemy == battler then return i end
		end
		for i, ally in session.allies do
			if ally == battler then return #session.enemies + i end
		end
		return 0
	end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SESSION EVENT WIRING
-- ══════════════════════════════════════════════════════════════════════════════

--- Wire up all network event listeners for a battle session.
--- This connects internal BattleSession events to client-facing packets.
function BattleNetworking.setupSessionEvents(session: any, activeSessions: { [number]: any }, cleanupCallback: ((session: any, data: any) -> ())?)
	-- Build per-player battler state (perspective-correct allies/enemies)
	local function sendBattleStateToPlayers()
		BattleNetworking.broadcastToSession(session, function(player)
			local userId = player.UserId
			local battlerStates = {}

			local playerOnAlliesTeam = false
			for _, ally in session.allies do
				if ally.userId == userId then playerOnAlliesTeam = true; break end
			end

			if playerOnAlliesTeam then
				for _, ally in session.allies do table.insert(battlerStates, BattleNetworking.serializeBattler(ally, true)) end
				for _, enemy in session.enemies do table.insert(battlerStates, BattleNetworking.serializeBattler(enemy, false)) end
			else
				for _, enemy in session.enemies do table.insert(battlerStates, BattleNetworking.serializeBattler(enemy, true)) end
				for _, ally in session.allies do table.insert(battlerStates, BattleNetworking.serializeBattler(ally, false)) end
			end

			return {
				battleId = tostring(session),
				status = session.status,
				turnCount = session.turnCount,
				battlerStates = HttpService:JSONEncode(battlerStates),
			}
		end, BattleEvents.packets.BattleStateUpdate.sendTo)
	end

	-- Send state immediately when battle starts
	task.defer(sendBattleStateToPlayers)

	-- Broadcast move announcement (BEFORE damage is calculated)
	session.events:subscribe("MoveStarted", function(data: any)
		BattleNetworking.broadcastToSession(session, function(player)
			local actorIndex = BattleNetworking.findBattlerIndexForPlayer(session, data.actor, player)
			local targetIndex = data.target and BattleNetworking.findBattlerIndexForPlayer(session, data.target, player) or 0
			return {
				battleId = tostring(session),
				actorIndex = actorIndex,
				moveName = data.moveName or "Unknown",
				targetIndex = targetIndex,
				targetType = data.targetType or "enemy",
				animationDuration = data.animationDuration or 1.0,
			}
		end, BattleEvents.packets.BattleMoveStarted.sendTo)
	end)

	-- Broadcast action execution to all players (AFTER damage calculated)
	session.events:subscribe("ActionExecuted", function(data: any)
		BattleNetworking.broadcastToSession(session, function(player)
			local actorIndex = BattleNetworking.findBattlerIndexForPlayer(session, data.actor, player)
			local targetIndex = data.target and BattleNetworking.findBattlerIndexForPlayer(session, data.target, player) or 0
			return {
				battleId = tostring(session),
				actorIndex = actorIndex,
				actionType = "move",
				moveName = data.moveName or "Unknown",
				targetIndex = targetIndex,
				targetType = data.targetType or "enemy",
				hit = data.hit,
				damage = data.damage,
				healing = data.healing,
				statusApplied = data.statusApplied,
				qteResult = data.qteResult,
				result = "{}",
			}
		end, BattleEvents.packets.BattleActionExecuted.sendTo)

		task.defer(sendBattleStateToPlayers)
	end)

	-- Send action prompts to players
	session.events:subscribe("PromptAction", function(data: any)
		local battler = data.battler
		if not battler.userId then return end

		local player = Players:GetPlayerByUserId(battler.userId)
		if not player then return end

		BattleEvents.packets.PromptAction.sendTo({
			battleId = tostring(session),
			battlerIndex = BattleNetworking.findBattlerIndexForPlayer(session, battler, player),
			availableMoves = battler.moves or {},
			timeLimit = 30.0,
		}, player)
	end)

	-- Send reaction prompts (parry/dodge/QTE)
	session.events:subscribe("PromptReaction", function(data: any)
		local player = Players:GetPlayerByUserId(data.userId)
		if not player then return end

		-- Encode available types in metadata so client can show multiple options
		local availableTypes = data.availableTypes or { data.windowType }
		local metadata = HttpService:JSONEncode({ availableTypes = availableTypes })

		BattleEvents.packets.PromptReaction.sendTo({
			reactionType = data.windowType, -- primary type for backward compat
			duration = data.duration,
			difficulty = 3,
			metadata = metadata,
		}, player)
	end)

	-- Broadcast status effect damage (burn/poison ticks)
	session.events:subscribe("StatusDamage", function(data: any)
		BattleNetworking.broadcastToSession(session, function(player)
			local battlerIndex = BattleNetworking.findBattlerIndexForPlayer(session, data.battler, player)
			return {
				battleId = tostring(session),
				actorIndex = battlerIndex,
				actionType = "status",
				moveName = data.status,
				targetIndex = battlerIndex,
				hit = true,
				damage = data.damage,
				result = "{}",
			}
		end, BattleEvents.packets.BattleActionExecuted.sendTo)

		task.defer(sendBattleStateToPlayers)
	end)

	-- Broadcast battle log entries (status applied, buffs, passives, etc.)
	session.events:subscribe("BattleLog", function(data: any)
		BattleNetworking.broadcastToSession(session, function(_player)
			return {
				battleId = tostring(session),
				message = data.message,
				category = data.category or "info",
			}
		end, BattleEvents.packets.BattleLog.sendTo)
	end)

	-- Broadcast battle end + cleanup
	session.events:subscribe("BattleEnd", function(data: any)
		-- Send VICTORY to winners, DEFEAT to losers
		for _, battler in data.winners do
			if battler.userId then
				local player = Players:GetPlayerByUserId(battler.userId)
				if player then
					BattleEvents.packets.BattleEnd.sendTo({
						battleId = tostring(session),
						result = "VICTORY",
						rewards = "{}",
					}, player)
				end
			end
		end

		for _, battler in data.losers do
			if battler.userId then
				local player = Players:GetPlayerByUserId(battler.userId)
				if player then
					BattleEvents.packets.BattleEnd.sendTo({
						battleId = tostring(session),
						result = "DEFEAT",
						rewards = "{}",
					}, player)
				end
			end
		end

		-- Delegate cleanup to caller
		if cleanupCallback then
			cleanupCallback(session, data)
		end
	end)
end

return BattleNetworking
