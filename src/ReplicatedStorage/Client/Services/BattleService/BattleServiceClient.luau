--!strict
--[=[
	Client-side battle service.
	Handles incoming battle events from the server and manages local battle state.

	Two-phase animation flow:
	  BattleMoveStarted  → start attack animation on actor (before damage)
	  BattleActionExecuted → resolve outcome (damage numbers, hit/dodge reaction)

	@class BattleServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local BattleEvents = require(ReplicatedStorage.Shared.Events.BattleEvents)
local BattleSignals = require(ReplicatedStorage.Client.Signals.BattleSignals)

local log = Logger.new("BattleServiceClient")

local BattleServiceClient = {}
BattleServiceClient.dependencies = {} :: { string }

local janitor = Janitor.new()

-- Current battle state
local currentBattle = nil :: {
	battleId: string,
	status: string,
	turnCount: number,
	allies: { any },
	enemies: { any },
}?

local currentPrompt = nil :: any?
local activeActorIndex = nil :: number?

-- ── Model Resolution ─────────────────────────────────────────────────────────
-- Maps battler index (1-based, allies then enemies) → workspace Model.
-- Built on BattleStarted, cleared on BattleEnded.

local _modelMap: { [number]: Model? } = {}
local function resolveModelForBattler(battler: any, index: number): Model?
	-- Player-controlled battler: use their Character
	if battler.userId then
		local player = Players:GetPlayerByUserId(battler.userId)
		if player and player.Character then
			return player.Character
		end
	end

	-- Use exact modelName from battler data if available (set server-side for proximity battles)
	if battler.modelName then
		local found = workspace:FindFirstChild(battler.modelName)
		if found and found:IsA("Model") then return found end
	end

	-- Server-spawned battle model: named "BattleChar_{modelName}_{slotIndex}"
	local modelName = battler.itemType or battler.characterId
	if modelName then
		local spawnedName = `BattleChar_{modelName}_{index}`
		local found = workspace:FindFirstChild(spawnedName)
		if found and found:IsA("Model") then return found end
	end

	return nil
end

local function buildModelMap()
	table.clear(_modelMap)
	if not currentBattle then return end

	for i, ally in currentBattle.allies do
		_modelMap[i] = resolveModelForBattler(ally, i)
	end
	local offset = #currentBattle.allies
	for i, enemy in currentBattle.enemies do
		_modelMap[offset + i] = resolveModelForBattler(enemy, offset + i)
	end

	log:debug(`Model map built: {#_modelMap} entries`)
end

local function getBattler(index: number): any?
	if not currentBattle then return nil end
	local all = {}
	for _, a in currentBattle.allies do table.insert(all, a) end
	for _, e in currentBattle.enemies do table.insert(all, e) end
	return all[index]
end

-- ── Init ─────────────────────────────────────────────────────────────────────

function BattleServiceClient.init(_self: any)
	log:info("Initializing BattleServiceClient")

	-- Listen for action prompts
	janitor:Add(BattleEvents.packets.PromptAction.listen(function(data)
		currentPrompt = {
			battleId       = data.battleId,
			availableMoves = data.availableMoves,
			timeLimit      = data.timeLimit,
			battlerIndex   = data.battlerIndex,
		}
		activeActorIndex = data.battlerIndex

		BattleSignals.ActionPrompted:Fire(currentPrompt)
	end))

	-- Listen for reaction prompts (QTE)
	janitor:Add(BattleEvents.packets.PromptReaction.listen(function(data)
		-- Decode available types from metadata (multi-reaction support)
		local availableTypes = { data.reactionType } -- fallback: just the primary type
		if data.metadata and data.metadata ~= "" then
			local ok, decoded = pcall(function() return HttpService:JSONDecode(data.metadata) end)
			if ok and decoded and decoded.availableTypes then
				availableTypes = decoded.availableTypes
			end
		end

		BattleSignals.ReactionPrompted:Fire({
			reactionType = data.reactionType,
			availableTypes = availableTypes,
			duration = data.duration,
		})
	end))

	-- Listen for battle state updates
	janitor:Add(BattleEvents.packets.BattleStateUpdate.listen(function(data)
		local battlerStates = HttpService:JSONDecode(data.battlerStates)

		local allies, enemies = {}, {}
		for _, b in battlerStates do
			if b.isAlly then table.insert(allies, b) else table.insert(enemies, b) end
		end

		if data.status == "ENDED" then
			BattleSignals.StateChanged:Fire({
				status = data.status, turnCount = data.turnCount,
				allies = allies, enemies = enemies,
			})
			return
		end

		-- Check if this is the first battle state (BEFORE updating currentBattle!)
		local isFirstUpdate = not currentBattle

		-- Snapshot previous HP by battler index so we can detect deaths after the update
		local prevHp: { [number]: number } = {}
		if currentBattle then
			for i, ally in currentBattle.allies do
				prevHp[i] = ally.currentHp or 0
			end
			local offset = #currentBattle.allies
			for i, enemy in currentBattle.enemies do
				prevHp[offset + i] = enemy.currentHp or 0
			end
		end

		-- Update local battle state
		currentBattle = {
			battleId = data.battleId,
			status = data.status,
			turnCount = data.turnCount,
			allies = allies,
			enemies = enemies,
		}

		if isFirstUpdate then
			-- Build model map now that we know who's in the battle
			buildModelMap()

			-- Start battle idle animations for all models
			local BattleAnimator = require(ReplicatedStorage.Client.UI.BattleUI.BattleAnimator)
			local allModels = {}
			for idx, model in _modelMap do
				local battler = getBattler(idx)
				if model and battler then
					table.insert(allModels, { model = model, characterId = battler.characterId })
				end
			end
			BattleAnimator.onBattleStart(allModels)

			BattleSignals.BattleStarted:Fire({ allies = allies, enemies = enemies })
		else
			-- Detect newly-dead battlers (HP just reached 0) and play death animation
			local BattleAnimator = require(ReplicatedStorage.Client.UI.BattleUI.BattleAnimator)
			local function checkDeaths(battlerList: { any }, indexOffset: number)
				for i, battler in battlerList do
					local idx = indexOffset + i
					if (prevHp[idx] or 1) > 0 and (battler.currentHp or 0) <= 0 then
						local model = _modelMap[idx]
						if model then
							BattleAnimator.playDeath(battler.characterId, model)
						end
					end
				end
			end
			checkDeaths(currentBattle.allies, 0)
			checkDeaths(currentBattle.enemies, #currentBattle.allies)

			BattleSignals.StateChanged:Fire({
				status = data.status, turnCount = data.turnCount,
				allies = allies, enemies = enemies,
			})
		end
	end))

	-- ── Phase 2: MoveStarted → start attack animation ───────────────────────
	janitor:Add(BattleEvents.packets.BattleMoveStarted.listen(function(data)
		task.spawn(function()
			local actor = getBattler(data.actorIndex)
			local characterId = actor and actor.characterId or nil
			local actorModel = _modelMap[data.actorIndex]
			
			activeActorIndex = data.actorIndex
			currentPrompt = nil

			-- Resolve all target models so the animator can midpoint multi-target camera focuses
			local targetModels: { Model } = {}
			if currentBattle then
				-- "allEnemies"/"allAllies" is relative to the ACTOR, not our perspective.
				-- If the actor is on our enemy side, their "enemies" are our allies and vice-versa.
				local actorIsEnemy = data.actorIndex > #currentBattle.allies
				if data.targetType == "allEnemies" then
					if actorIsEnemy then
						for i = 1, #currentBattle.allies do
							local m = _modelMap[i]
							if m then table.insert(targetModels, m) end
						end
					else
						local offset = #currentBattle.allies
						for i = 1, #currentBattle.enemies do
							local m = _modelMap[offset + i]
							if m then table.insert(targetModels, m) end
						end
					end
				elseif data.targetType == "allAllies" then
					if actorIsEnemy then
						local offset = #currentBattle.allies
						for i = 1, #currentBattle.enemies do
							local m = _modelMap[offset + i]
							if m then table.insert(targetModels, m) end
						end
					else
						for i = 1, #currentBattle.allies do
							local m = _modelMap[i]
							if m then table.insert(targetModels, m) end
						end
					end
				else
					local m = _modelMap[data.targetIndex]
					if m then table.insert(targetModels, m) end
				end
			end

			local BattleAnimator = require(ReplicatedStorage.Client.UI.BattleUI.BattleAnimator)
			BattleAnimator.playAttack(characterId, data.moveName, actorModel, targetModels)

			BattleSignals.MoveStarted:Fire({
				actorIndex = data.actorIndex,
				moveName = data.moveName,
				targetIndex = data.targetIndex,
				targetType = data.targetType,
				animationDuration = data.animationDuration,
			})
		end)
	end))

	-- ── ActionExecuted → resolve outcome (damage, reactions) ─────────────────
	janitor:Add(BattleEvents.packets.BattleActionExecuted.listen(function(data)
		task.spawn(function()
			-- Only play move animations for actual moves, not status ticks
			if data.actionType ~= "status" then
				local BattleAnimator = require(ReplicatedStorage.Client.UI.BattleUI.BattleAnimator)
				local target = getBattler(data.targetIndex)
				local targetModel = _modelMap[data.targetIndex]

				BattleAnimator.resolveOutcome({
					damage = data.damage,
					healing = data.healing,
					hit = data.hit,
					statusApplied = data.statusApplied,
					qteResult = data.qteResult,
					targetModel = targetModel,
					targetCharacterId = target and target.characterId or nil,
				})
			end
			
			activeActorIndex = nil

			BattleSignals.ActionExecuted:Fire({
				actorIndex    = data.actorIndex,
				actionType    = data.actionType,
				moveName      = data.moveName,
				targetIndex   = data.targetIndex,
				targetType    = data.targetType,
				hit           = data.hit,
				damage        = data.damage,
				healing       = data.healing,
				statusApplied = data.statusApplied,
				qteResult     = data.qteResult,
			})
		end)
	end))

	-- Battle log
	janitor:Add(BattleEvents.packets.BattleLog.listen(function(data)
		BattleSignals.BattleLog:Fire({ message = data.message, category = data.category })
	end))

	-- Battle end
	janitor:Add(BattleEvents.packets.BattleEnd.listen(function(data)
		local BattleAnimator = require(ReplicatedStorage.Client.UI.BattleUI.BattleAnimator)
		BattleAnimator.onBattleEnd()

		BattleSignals.BattleEnded:Fire({ result = data.result, rewards = data.rewards })

		table.clear(_modelMap)
		currentBattle = nil
		currentPrompt = nil
		activeActorIndex = nil

		if data.result == "VICTORY" then
			log:info("VICTORY!")
		elseif data.result == "DEFEAT" then
			log:info("DEFEAT!")
		end
	end))

	log:info("BattleServiceClient initialized")
end

--[=[
	Cleans up event listeners when the service is stopped.
]=]
function BattleServiceClient.stop(_self: any)
	janitor:Cleanup()
	table.clear(_modelMap)
	log:debug("Service stopped")
end

--[=[
	Gets the current battle state (if in a battle).
	@return table? -- Current battle state or nil
]=]
function BattleServiceClient:getCurrentBattle()
	return currentBattle
end

--[=[
	Checks if the player is currently in a battle.
	@return boolean
]=]
function BattleServiceClient:isInBattle(): boolean
	return currentBattle ~= nil
end

--[=[
	Returns the model for a battler index.
	@param index: number -- Battler index (1-based, allies then enemies)
	@return Model? -- The model or nil if not found
]=]
function BattleServiceClient:getModelForIndex(index: number): Model?
	return _modelMap[index]
end

function BattleServiceClient:getCurrentPrompt()
	return currentPrompt
end

function BattleServiceClient:getActiveActorIndex()
	return activeActorIndex
end

--[=[
	Returns the current state of the service for debugging.
	@return { [string]: any } -- Service state
]=]
function BattleServiceClient:getState(): { [string]: any }
	return {
		isInBattle = self:isInBattle(),
		currentBattle = currentBattle,
	}
end

type BattleServiceClient = typeof(BattleServiceClient)

return BattleServiceClient :: BattleServiceClient
