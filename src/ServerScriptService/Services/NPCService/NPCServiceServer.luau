--!strict
--[=[
	NPCServiceServer - Manages enemy NPC spawning, proximity detection, and battle triggers.
	
	Each NPC is a character model placed in workspace with metadata attributes:
	- characterId: string (e.g. "NATSU")
	- level: number
	- aggroRadius: number (studs — how close a player must be to trigger battle)
	
	When a player walks within aggroRadius of an NPC, a battle callback fires.
	The existing models are reused (walked to battle positions) instead of spawning new ones.
	
	@class NPCServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CharacterDefinitions = require(ServerScriptService.Modules.Battle.Characters.CharacterDefinitions)
local CharacterModelManager = require(ServerScriptService.Modules.Battle.CharacterModelManager)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

local log = Logger.new("NPCServiceServer")

local NPCServiceServer = {}
NPCServiceServer.dependencies = {} :: { string }

-- All active NPCs: { model: Model, characterId: string, level: number, aggroRadius: number, inBattle: boolean }
local activeNPCs: { [string]: NPCData } = {}

-- Cooldown per player to prevent instant re-aggro after battle ends
local playerCooldowns: { [number]: number } = {}

local COOLDOWN_DURATION = 5 -- seconds after battle before can be aggro'd again

export type NPCData = {
	model: Model,
	characterId: string,
	level: number,
	aggroRadius: number,
	inBattle: boolean,
	spawnCFrame: CFrame,
}

-- Callback set by the battle system to handle proximity battles
local onBattleTrigger: ((player: Player, npcData: NPCData) -> ())? = nil

-- ══════════════════════════════════════════════════════════════════════════════
-- SERVICE LIFECYCLE
-- ══════════════════════════════════════════════════════════════════════════════

function NPCServiceServer.init(_self: any)
	log:info("NPCServiceServer initialized")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PUBLIC API
-- ══════════════════════════════════════════════════════════════════════════════

--- Spawn an NPC at the given position.
function NPCServiceServer.spawnNPC(config: {
	characterId: string,
	level: number?,
	position: CFrame,
	aggroRadius: number?,
	parent: Instance?,
}): Model?
	local characterId = string.upper(config.characterId)
	local charDef = CharacterDefinitions.getCharacterById(characterId)
	if not charDef then
		warn(`[NPCServiceServer] Unknown character: {characterId}`)
		return nil
	end

	local model = CharacterModelManager.spawnModel(
		characterId,
		nil, -- no userId for NPCs
		#activeNPCs + 100, -- offset slot index to avoid collision with battle slots
		config.position,
		config.parent or workspace
	)

	if not model then
		warn(`[NPCServiceServer] Failed to spawn model for {characterId}`)
		return nil
	end

	local npcId = `npc_{characterId}_{tick()}`
	model:SetAttribute("npcId", npcId)
	model:SetAttribute("characterId", characterId)
	model:SetAttribute("level", config.level or 50)

	activeNPCs[npcId] = {
		model = model,
		characterId = characterId,
		level = config.level or 50,
		aggroRadius = config.aggroRadius or 20,
		inBattle = false,
		spawnCFrame = config.position,
	}

	log:info(`Spawned NPC {charDef.name} (Lv.{config.level or 50}) at {config.position.Position}`)
	return model
end

--- Remove an NPC from the world.
function NPCServiceServer.despawnNPC(npcId: string)
	local npc = activeNPCs[npcId]
	if npc then
		if npc.model and npc.model.Parent then
			npc.model:Destroy()
		end
		activeNPCs[npcId] = nil
	end
end

--- Mark an NPC as no longer in battle and return it to its spawn position.
function NPCServiceServer.releaseNPC(npcId: string)
	local npc = activeNPCs[npcId]
	if npc then
		npc.inBattle = false
		if npc.model and npc.model.PrimaryPart then
			npc.model:PivotTo(npc.spawnCFrame)
		end
	end
end

--- Get NPC data by ID.
function NPCServiceServer.getNPC(npcId: string): NPCData?
	return activeNPCs[npcId]
end

--- Get NPC data from a model instance.
function NPCServiceServer.getNPCFromModel(model: Model): NPCData?
	local npcId = model:GetAttribute("npcId")
	if npcId then
		return activeNPCs[npcId]
	end
	return nil
end

--- Register the callback that fires when a player triggers a battle with an NPC.
function NPCServiceServer.onBattleTriggered(callback: (player: Player, npcData: NPCData) -> ())
	onBattleTrigger = callback
end

--- Set a player's cooldown (e.g., after battle ends).
function NPCServiceServer.setPlayerCooldown(userId: number)
	playerCooldowns[userId] = tick() + COOLDOWN_DURATION
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PROXIMITY DETECTION LOOP
-- ══════════════════════════════════════════════════════════════════════════════

function NPCServiceServer.startProximityLoop()
	RunService.Heartbeat:Connect(function()
		local now = tick()

		for _npcId, npc in activeNPCs do
			if npc.inBattle then continue end
			if not npc.model or not npc.model.Parent then continue end

			local npcPos = npc.model.PrimaryPart and npc.model.PrimaryPart.Position
			if not npcPos then continue end

			for _, player in Players:GetPlayers() do
				if playerCooldowns[player.UserId] and now < playerCooldowns[player.UserId] then
					continue
				end

				local character = player.Character
				if not character then continue end
				local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not rootPart then continue end

				local dist = (rootPart.Position - npcPos).Magnitude
				if dist <= npc.aggroRadius then
					npc.inBattle = true
					playerCooldowns[player.UserId] = now + COOLDOWN_DURATION

					log:info(`{player.Name} triggered battle with NPC {npc.characterId} (dist={math.floor(dist)})`)

					if onBattleTrigger then
						task.spawn(onBattleTrigger, player, npc)
					end

					break -- one trigger per NPC per frame
				end
			end
		end
	end)
end

return NPCServiceServer
