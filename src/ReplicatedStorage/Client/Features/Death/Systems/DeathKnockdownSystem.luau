--!strict
--[=[
	DeathKnockdownSystem: the local player's knockdown pose. The server marks the character down
	(DeathConstants.KNOCKDOWN_ATTRIBUTE = the throw) and clears the mark when they get up (server
	DeathKnockdownSystem); this client owns its character's physics, so it plays the mark like Cargo's slip:
	PlatformStand and the throw on the way down, PlatformStand off and GettingUp on the way up
	(DeathKnockdownUtils.next decides). While down the gameplay actions (the vacuum, the hotbar) are silenced by a
	sinking `ui` input context; the server refuses them anyway.

	The throw waits for the root to be free: a catch anchors it and releases it in the same server step that marks
	the knockdown. While down, PlatformStand is held (a slip's delayed restore cannot stand them up early). A
	character that dies keeps its body as it is (the controls come back for the spectate); a character that goes
	(a reset, a respawn) takes everything with it, and the new one starts up.

	Spec-exempt shell (Humanoid, physics, Input); the decisions are the specced DeathKnockdownUtils.

	@class DeathKnockdownSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local DeathKnockdownUtils = require(ReplicatedStorage.Shared.Features.Death.Utils.DeathKnockdownUtils)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)

-- How long a throw waits for an anchored root to be released before it is dropped.
local THROW_WAIT = 1

-- Watches one character; returns its cleanup.
local function watch(character: Model): () -> ()
	local found = character:WaitForChild("Humanoid", 5)
	local rootFound = character:WaitForChild("HumanoidRootPart", 5)
	if found == nil or not found:IsA("Humanoid") or rootFound == nil or not rootFound:IsA("BasePart") then
		return function() end
	end
	local humanoid: Humanoid = found
	local root: BasePart = rootFound
	local down = false
	local inputToken: number? = nil
	local connections: { RBXScriptConnection } = {}
	local pendingThrow: RBXScriptConnection? = nil

	local function releaseInput()
		local token = inputToken
		inputToken = nil
		if token ~= nil then
			InputServiceClient:removeContext(token)
		end
	end

	local function dropPendingThrow()
		local pending = pendingThrow
		pendingThrow = nil
		if pending ~= nil then
			pending:Disconnect()
		end
	end

	local function throw(launch: Vector3)
		dropPendingThrow()
		if not root.Anchored then
			root.AssemblyLinearVelocity = launch
			return
		end
		local waiting = root:GetPropertyChangedSignal("Anchored"):Connect(function()
			if not root.Anchored then
				dropPendingThrow()
				root.AssemblyLinearVelocity = launch
			end
		end)
		pendingThrow = waiting
		task.delay(THROW_WAIT, function()
			if pendingThrow == waiting then
				dropPendingThrow()
			end
		end)
	end

	local function apply()
		local value = character:GetAttribute(DeathConstants.KNOCKDOWN_ATTRIBUTE)
		local step = DeathKnockdownUtils.next(down, value, humanoid.Health > 0)
		if step == "fall" then
			down = true
			humanoid.PlatformStand = true
			if inputToken == nil then
				inputToken = InputServiceClient:pushContext("ui", { sink = true })
			end
			local launch = DeathKnockdownUtils.launchOf(value)
			if launch ~= nil then
				throw(launch)
			end
		elseif step == "rise" then
			down = false
			dropPendingThrow()
			releaseInput()
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		elseif step == "release" then
			down = false
			dropPendingThrow()
			releaseInput()
		end
	end

	table.insert(connections, character:GetAttributeChangedSignal(DeathConstants.KNOCKDOWN_ATTRIBUTE):Connect(apply))
	table.insert(connections, humanoid.Died:Connect(apply))
	-- Held down: something else turning PlatformStand off (a slip's restore) does not stand them up early.
	table.insert(
		connections,
		humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
			if down and not humanoid.PlatformStand and humanoid.Health > 0 then
				humanoid.PlatformStand = true
			end
		end)
	)
	-- The mark may already be set when the character is first seen.
	apply()

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		dropPendingThrow()
		releaseInput()
		if down and humanoid.Parent ~= nil and humanoid.Health > 0 then
			humanoid.PlatformStand = false
		end
		down = false
	end
end

local DeathKnockdownSystem = {}

--[=[
	Plays the knockdown on each local character. Returns the stopper.
]=]
function DeathKnockdownSystem.start(): () -> ()
	local player = Players.LocalPlayer
	local cleanup: (() -> ())? = nil
	local generation = 0

	local function stopWatching()
		local current = cleanup
		cleanup = nil
		if current ~= nil then
			current()
		end
	end

	local function onCharacter(character: Model)
		stopWatching()
		generation += 1
		local mine = generation
		task.spawn(function()
			local stop = watch(character)
			if generation == mine and character.Parent ~= nil then
				cleanup = stop
			else
				stop()
			end
		end)
	end

	local added = player.CharacterAdded:Connect(onCharacter)
	local removing = player.CharacterRemoving:Connect(function()
		generation += 1
		stopWatching()
	end)
	if player.Character ~= nil then
		onCharacter(player.Character)
	end
	return function()
		added:Disconnect()
		removing:Disconnect()
		generation += 1
		stopWatching()
	end
end

return DeathKnockdownSystem
