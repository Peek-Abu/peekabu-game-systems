--!strict
--[=[
	Service for handling defender QTE input (Dodge, Parry) via keyboard.
	NO UI - players time their reactions based on the attack animation.
	
	Controls:
	- Q = Dodge (short cooldown: 2s)
	- E = Parry (longer cooldown: 4s)
	
	Timing:
	- Can trigger anytime during the reaction window
	- If triggered outside window, goes on cooldown but fails
	- Mistimed dodge: character rolls but returns to get hit
	
	@class ReactionInputServiceClient
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BattleEvents = require(ReplicatedStorage.Shared.Events.BattleEvents)
local BattleSignals = require(ReplicatedStorage.Client.Signals.BattleSignals)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

local log = Logger.new("ReactionInputServiceClient")

local ReactionInputServiceClient = {}

local janitor = Janitor.new()

-- Cooldown tracking
local cooldowns = {
	dodge = 0,
	parry = 0,
}

local COOLDOWN_DODGE = 2.0 -- seconds
local COOLDOWN_PARRY = 4.0 -- seconds

-- Active reaction window state
local activeWindow: {
	userId: number,
	availableTypes: { string },
	startTime: number,
	duration: number,
}?

-- Generic attack window (for moves without defined reactions)
local genericAttackWindow: {
	startTime: number,
	duration: number,
}?

-- Default duration for generic attacks (if no reaction window defined)
local DEFAULT_REACTION_DURATION = 1.0

-- Track characters belonging to the local player that are currently being targeted
local targetedCharacters: { { characterId: string, model: Model } } = {}
local currentAttackVersion = 0

--[=[
	Check if we're currently in ANY reaction window (specific or generic)
]=]
local function isInAnyWindow(): boolean
	-- Check specific reaction window
	if activeWindow then
		local elapsed = os.clock() - activeWindow.startTime
		if elapsed <= activeWindow.duration then
			return true
		end
	end
	
	-- Check generic attack window
	if genericAttackWindow then
		local elapsed = os.clock() - genericAttackWindow.startTime
		if elapsed <= genericAttackWindow.duration then
			return true
		end
	end
	
	return false
end

--[=[
	Submit a reaction to the server
]=]
local function submitReaction(reactionType: string)
	local player = Players.LocalPlayer
	if not player then return end
	
	-- Send to server (use .send() for client->server, not .sendToServer())
	BattleEvents.packets.SubmitReaction.send({
		reactionType = reactionType,
		timingDelta = 0, -- Will be calculated server-side based on when window opened
		accuracy = 1.0,
		inputSequence = "{}",
	})
	
	log:debug(`Submitted {reactionType} reaction`)
end

--[=[
	Play dodge roll animation on the specified models
]=]
local function playDodgeAnimations(targets: { { characterId: string, model: Model } })
	local BattleAnimator = require(ReplicatedStorage.Client.UI.BattleUI.BattleAnimator)
	
	for _, target in targets do
		local character = target.model
		local characterId = target.characterId
		
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then continue end

		-- Store original CFrame before moving
		local originalCFrame = root.CFrame

		-- Dodge backwards (away from the attacker)
		local dodgeDirection = -root.CFrame.LookVector

		-- Use linear velocity for a quick burst
		local bv = Instance.new("LinearVelocity")
		bv.MaxForce = math.huge
		bv.VectorVelocity = dodgeDirection * 24
		bv.Attachment0 = root:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", root)
		bv.Parent = root

		-- Remove after short time, then tween back
		task.delay(0.3, function()
			if bv then bv:Destroy() end
			task.delay(0.1, function()
				if not root or not root:IsA("BasePart") then return end
				local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				local targetCFrame = CFrame.new(originalCFrame.Position) * (root.CFrame - root.CFrame.Position)
				TweenService:Create(root, tweenInfo, { CFrame = targetCFrame }):Play()
			end)
		end)

		-- Play character-specific dodge animation
		BattleAnimator.playDodge(characterId, character)
	end
end

--[=[
	Handle dodge input
]=]
local function onDodgeInput()
	local now = os.clock()
	
	-- Check cooldown
	if now < cooldowns.dodge then
		return
	end
	
	-- MUST be in a window (targeted) to dodge
	if not isInAnyWindow() then
		return
	end

	-- Set cooldown
	cooldowns.dodge = now + COOLDOWN_DODGE
	
	-- Play animation for all targeted characters
	playDodgeAnimations(targetedCharacters)
	
	submitReaction("Dodge")
	log:info("Dodge successful!")
end

--[=[
	Play parry block animation on the specified models
]=]
local function playParryAnimations(targets: { { characterId: string, model: Model } })
	local BattleAnimator = require(ReplicatedStorage.Client.UI.BattleUI.BattleAnimator)
	for _, target in targets do
		BattleAnimator.playParry(target.characterId, target.model)
	end
end

--[=[
	Handle parry input
]=]
local function onParryInput()
	local now = os.clock()
	
	-- Check cooldown
	if now < cooldowns.parry then
		return
	end
	
	-- MUST be in a window (targeted) to parry
	if not isInAnyWindow() then
		return
	end

	-- Set cooldown
	cooldowns.parry = now + COOLDOWN_PARRY
	
	-- Play animation for all targeted characters
	playParryAnimations(targetedCharacters)
	
	submitReaction("Parry")
	log:info("Parry successful!")
end

--[=[
	Initialize the service
]=]
function ReactionInputServiceClient.init(_self: any)
	log:info("Initializing ReactionInputServiceClient")
	
	-- Listen for reaction prompts from server (specific reactions like Parry/Dodge windows)
	janitor:Add(BattleSignals.ReactionPrompted:Connect(function(data)
		
		activeWindow = {
			userId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0,
			availableTypes = data.availableTypes or { data.reactionType },
			startTime = os.clock(),
			duration = data.duration or 0.5,
		}
		
		-- Auto-clear after window duration
		task.delay(activeWindow.duration + 0.1, function()
			if activeWindow and os.clock() >= activeWindow.startTime + activeWindow.duration then
				activeWindow = nil
				BattleSignals.ReactionWindowEnded:Fire({})
			end
		end)
	end), "Disconnect")
	
	-- Listen for ANY attack starting (for moves without defined reactions)
	janitor:Add(BattleSignals.MoveStarted:Connect(function(data)
		local player = Players.LocalPlayer
		if not player then return end
		
		local battleSvc = nil
		pcall(function()
			local ServiceController = require(ReplicatedStorage.Shared.Modules.ServiceController)
			battleSvc = ServiceController:getService("BattleServiceClient")
		end)
		
		if not battleSvc then return end
		
		-- Check if player is the target
		local currentBattle = battleSvc:getCurrentBattle()
		if not currentBattle then return end
		
		-- Identify all characters belonging to the player that are targeted by this move
		currentAttackVersion += 1
		local myVersion = currentAttackVersion
		table.clear(targetedCharacters)
		
		local actorIsEnemy = data.actorIndex > #currentBattle.allies
		
		for i, ally in currentBattle.allies do
			if ally.userId == player.UserId then
				local isTargeted = false
				if data.targetType == "allEnemies" then
					if actorIsEnemy then isTargeted = true end
				elseif data.targetType == "allAllies" then
					if not actorIsEnemy then isTargeted = true end
				elseif data.targetType == "self" then
					if data.actorIndex == i then isTargeted = true end
				elseif data.targetIndex == i then
					isTargeted = true
				end
				
				if isTargeted then
					local model = battleSvc:getModelForIndex(i)
					if model then
						table.insert(targetedCharacters, { characterId = ally.characterId, model = model })
					end
				end
			end
		end
		
		if #targetedCharacters > 0 then
			log:debug(`Attack {data.moveName} targeting {#targetedCharacters} player characters - opening generic reaction window`)
			
			-- Open a generic window for this attack (no specific reaction types)
			genericAttackWindow = {
				startTime = os.clock(),
				duration = data.animationDuration or DEFAULT_REACTION_DURATION,
			}
			
			-- Auto-clear after duration
			task.delay(genericAttackWindow.duration + 0.1, function()
				if currentAttackVersion == myVersion then
					genericAttackWindow = nil
					table.clear(targetedCharacters)
				end
			end)
		end
	end), "Disconnect")
	
	-- Listen for input
	janitor:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- Q = Dodge
		if input.KeyCode == Enum.KeyCode.Q then
			onDodgeInput()
		-- E = Parry
		elseif input.KeyCode == Enum.KeyCode.E then
			onParryInput()
		end
	end))
end

--[=[
	Stop the service
]=]
function ReactionInputServiceClient.stop(_self: any)
	janitor:Cleanup()
	activeWindow = nil
end

--[=[
	Get current cooldowns (for UI/debugging)
]=]
function ReactionInputServiceClient:getCooldowns(): { dodge: number, parry: number }
	local now = os.clock()
	return {
		dodge = math.max(0, cooldowns.dodge - now),
		parry = math.max(0, cooldowns.parry - now),
	}
end

--[=[
	Check if a reaction window is active
]=]
function ReactionInputServiceClient:isWindowActive(): boolean
	return isInAnyWindow()
end

--[=[
	Get available reactions in current window
]=]
function ReactionInputServiceClient:getAvailableReactions(): { string }?
	if not activeWindow then return nil end
	return activeWindow.availableTypes
end

return ReactionInputServiceClient
