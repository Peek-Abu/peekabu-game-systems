--!strict
--[=[
	CharacterModelManager - Spawns, positions, and despawns character models for battles.
	
	Models are expected in ReplicatedStorage.Shared.Assets.CharacterModels
	named to match CharacterDefinitions.model (e.g. "GokuCharacter").
	
	@class CharacterModelManager
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterDefinitions = require(ServerScriptService.Modules.Battle.Characters.CharacterDefinitions)

local CharacterModelManager = {}

-- Active model instances keyed by a unique battle key (e.g. "userId_characterId" or "npc_slotIndex")
local activeModels: { [string]: Model } = {}

local MODELS_FOLDER = ReplicatedStorage:FindFirstChild("Shared")
	and ReplicatedStorage.Shared:FindFirstChild("Assets")
	and ReplicatedStorage.Shared.Assets:FindFirstChild("CharacterModels")

-- ══════════════════════════════════════════════════════════════════════════════
-- INTERNAL HELPERS
-- ══════════════════════════════════════════════════════════════════════════════

local function getModelTemplate(modelName: string): Model?
	if not MODELS_FOLDER then
		warn("[CharacterModelManager] CharacterModels folder not found in ReplicatedStorage.Shared.Assets")
		return nil
	end
	return MODELS_FOLDER:FindFirstChild(modelName) :: Model?
end

local function generateKey(userId: number?, slotIndex: number): string
	if userId then
		return `player_{userId}_{slotIndex}`
	end
	return `npc_{slotIndex}`
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PUBLIC API
-- ══════════════════════════════════════════════════════════════════════════════

--- Spawn a character model at the given CFrame.
--- Returns the model instance or nil if the template is missing.
function CharacterModelManager.spawnModel(
	characterId: string,
	userId: number?,
	slotIndex: number,
	cframe: CFrame,
	parent: Instance?
): Model?
	local charDef = CharacterDefinitions.getCharacterById(characterId)
	if not charDef or not charDef.model then
		warn(`[CharacterModelManager] No model defined for character: {characterId}`)
		return nil
	end

	local template = getModelTemplate(charDef.model)
	if not template then
		warn(`[CharacterModelManager] Model template "{charDef.model}" not found`)
		return nil
	end

	local model = template:Clone()
	model.Name = `BattleChar_{charDef.model}_{slotIndex}`

	-- Position the model
	if model:IsA("Model") and model.PrimaryPart then
		model:PivotTo(cframe)
	end

	model.Parent = parent or workspace

	-- Track it
	local key = generateKey(userId, slotIndex)
	activeModels[key] = model

	return model
end

--- Despawn a specific character model.
function CharacterModelManager.despawnModel(userId: number?, slotIndex: number)
	local key = generateKey(userId, slotIndex)
	local model = activeModels[key]
	if model then
		model:Destroy()
		activeModels[key] = nil
	end
end

--- Despawn all active battle models.
function CharacterModelManager.despawnAll()
	for key, model in activeModels do
		model:Destroy()
		activeModels[key] = nil
	end
end

--- Get an active model instance.
function CharacterModelManager.getModel(userId: number?, slotIndex: number): Model?
	local key = generateKey(userId, slotIndex)
	return activeModels[key]
end

--- Spawn all battlers for a battle session.
--- allies and enemies are arrays of Battler objects.
--- Returns { allies: {Model?}, enemies: {Model?} }
function CharacterModelManager.spawnBattleModels(
	allies: { any },
	enemies: { any },
	battleArena: CFrame?
): { allies: { Model? }, enemies: { Model? } }
	local origin = battleArena or CFrame.new(0, 5, 0)
	local allyModels = {}
	local enemyModels = {}

	-- Spawn allies (facing +Z)
	for i, battler in allies do
		local offset = CFrame.new((i - 1) * 6 - (#allies - 1) * 3, 0, 8)
		local spawnCF = origin * offset
		local model = CharacterModelManager.spawnModel(
			battler.characterId or "GOKU",
			battler.userId,
			i,
			spawnCF
		)
		table.insert(allyModels, model)
	end

	-- Spawn enemies (facing -Z, rotated 180)
	for i, battler in enemies do
		local offset = CFrame.new((i - 1) * 6 - (#enemies - 1) * 3, 0, -8) * CFrame.Angles(0, math.pi, 0)
		local spawnCF = origin * offset
		local model = CharacterModelManager.spawnModel(
			battler.characterId or "NATSU",
			battler.userId,
			#allies + i,
			spawnCF
		)
		table.insert(enemyModels, model)
	end

	return { allies = allyModels, enemies = enemyModels }
end

--- Walk/tween an existing model to a target CFrame over the given duration.
--- If the model has a Humanoid, sets WalkSpeed so it arrives in exactly `duration` seconds,
--- then stops and snaps to exact CFrame. Otherwise tweens the PrimaryPart.
function CharacterModelManager.walkModelTo(model: Model, targetCFrame: CFrame, duration: number?): ()
	if not model or not model.Parent then return end

	local TweenService = game:GetService("TweenService")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local moveDuration = duration or 1.5

	if humanoid and model.PrimaryPart then
		local hrp = model.PrimaryPart
		-- Flatten travel to XZ only — avoids Y-component corrupting speed/distance calc
		local actorPos = hrp.Position
		local destPos2D = Vector3.new(targetCFrame.Position.X, actorPos.Y, targetCFrame.Position.Z)
		local travelDist = (destPos2D - actorPos).Magnitude
		local prevSpeed = humanoid.WalkSpeed

		-- Set speed so character arrives in exactly moveDuration seconds
		local requiredSpeed = if moveDuration > 0 and travelDist > 0.1 then travelDist / moveDuration else prevSpeed
		humanoid.WalkSpeed = requiredSpeed
		humanoid:MoveTo(targetCFrame.Position)

		-- Wait exactly moveDuration, not for MoveToFinished (which can arrive early/late)
		task.wait(moveDuration)

		-- Stop movement and snap to exact destination.
		-- CRITICAL: zero AssemblyLinearVelocity BEFORE PivotTo, otherwise physics
		-- carries residual momentum through the snap and causes drift every move.
		if model.Parent then
			humanoid.WalkSpeed = 0
			humanoid:MoveTo(hrp.Position)
			if hrp:IsA("BasePart") then
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
			model:PivotTo(targetCFrame)
		end
	elseif model.PrimaryPart then
		-- Tween non-humanoid models
		local tween = TweenService:Create(
			model.PrimaryPart,
			TweenInfo.new(moveDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ CFrame = targetCFrame }
		)
		tween:Play()
		tween.Completed:Wait()
	end
end

--- Track a pre-existing model (e.g. a player's character or an NPC already on the map)
--- so the battle system can reference it instead of spawning a new one.
function CharacterModelManager.trackExistingModel(key: string, model: Model)
	activeModels[key] = model
end

--- Untrack a model without destroying it (for models that persist after battle).
function CharacterModelManager.untrackModel(key: string)
	activeModels[key] = nil
end

--- Change a player's character model (used by admin commands).
--- Morphs the player's Roblox character into the battle character model.
function CharacterModelManager.morphPlayer(player: Player, characterId: string): boolean
	local charDef = CharacterDefinitions.getCharacterById(characterId)
	if not charDef or not charDef.model then
		warn(`[CharacterModelManager] Cannot morph: no model for {characterId}`)
		return false
	end
	print(`[CharacterModelManager] Morphing player {player.Name} to character {characterId}`)
	local template = getModelTemplate(charDef.model)
	if not template then
		warn(`[CharacterModelManager] Cannot morph: template "{charDef.model}" not found`)
		return false
	end

	local oldCharacter = player.Character
	if not oldCharacter then
		warn(`[CharacterModelManager] Cannot morph: player has no character`)
		return false
	end
	local pivotCFrame = oldCharacter:GetPivot()
	local newCharacter = template:Clone()
	newCharacter.Name = player.Name
	newCharacter.Parent = workspace
	newCharacter:PivotTo(pivotCFrame)
	player.Character = newCharacter

	return true
end

return CharacterModelManager
