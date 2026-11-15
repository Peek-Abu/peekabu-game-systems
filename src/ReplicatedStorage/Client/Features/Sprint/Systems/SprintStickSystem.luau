--!strict
--[=[
	SprintStickSystem: on a touch screen, pushing the move stick far out is the run (phone Layout 2, owner pick 11-15;
	SprintConstants.STICK_RUN, which also switches it off and brings the SPRINT button back). Every frame while the last
	input was a touch, it reads how far the character's move action is pushed (the Input Action System's
	`CharacterContext.MoveAction`, the action Roblox's own touch thumbstick drives) and asks SprintRules.stickRun whether
	that is a run; a change is handed to `onHeld` (SprintServiceClient, which tells the server; the server still decides).
	A keyboard or gamepad as the last input never runs by stick: Shift and L3 do that, and a held W reads as a full push.

	Where the place runs the legacy player scripts (no MoveAction) it never runs and warns once.

	@class SprintStickSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local SprintConstants = require(ReplicatedStorage.Shared.Features.Sprint.Data.SprintConstants)
local SprintRules = require(ReplicatedStorage.Shared.Features.Sprint.Rules.SprintRules)
local CrouchStore = require(ReplicatedStorage.Client.Features.Crouch.State.CrouchStore)

local SprintStickSystem = {}

local connection: RBXScriptConnection? = nil
local held = false
local warned = false

local function moveIn(contexts: Instance?): InputAction?
	local context = if contexts ~= nil then contexts:FindFirstChild("CharacterContext") else nil
	local action = if context ~= nil then context:FindFirstChild("MoveAction") else nil
	if action ~= nil and action:IsA("InputAction") then
		return action
	end
	return nil
end

--[=[
	The character's move action: the player's own clone of the contexts first (server-authority places drive the
	character from it), else `StarterPlayer.PlayerModule.InputContexts.CharacterContext.MoveAction`. Pure lookup.
]=]
function SprintStickSystem.findMoveAction(starterPlayer: Instance, player: Instance?): InputAction?
	local mine = moveIn(if player ~= nil then player:FindFirstChild("InputContexts") else nil)
	if mine ~= nil then
		return mine
	end
	local playerModule = starterPlayer:FindFirstChild("PlayerModule")
	return moveIn(if playerModule ~= nil then playerModule:FindFirstChild("InputContexts") else nil)
end

--[=[
	How far (0-1) a move action's state is pushed: a direction's length; anything else reads as 0.
]=]
function SprintStickSystem.magnitudeOf(state: unknown): number
	if typeof(state) == "Vector2" then
		return math.min(state.Magnitude, 1)
	elseif typeof(state) == "Vector3" then
		return math.min(state.Magnitude, 1)
	end
	return 0
end

--[=[
	Starts reading the stick (a touch device with STICK_RUN on; otherwise a no-op). `onHeld` gets every change of
	whether the stick asks for a run.
]=]
function SprintStickSystem.start(onHeld: (held: boolean) -> ())
	local settings = SprintConstants.STICK_RUN
	if connection ~= nil or not settings.enabled or not UserInputService.TouchEnabled then
		return
	end
	local player = Players.LocalPlayer
	local action: InputAction? = nil
	connection = RunService.Heartbeat:Connect(function()
		if action == nil or action.Parent == nil then
			action = SprintStickSystem.findMoveAction(StarterPlayer, player)
			if action == nil and not warned then
				warned = true
				warn("[SprintStickSystem] no CharacterContext.MoveAction; the stick cannot run")
			end
		end
		local touching = UserInputService:GetLastInputType() == Enum.UserInputType.Touch
		local magnitude = if action ~= nil and touching then SprintStickSystem.magnitudeOf(action:GetState()) else 0
		local next = SprintRules.stickRun(magnitude, CrouchStore.crouching(), held, settings)
		if next ~= held then
			held = next
			onHeld(held)
		end
	end)
end

function SprintStickSystem.stop()
	local live = connection
	if live ~= nil then
		live:Disconnect()
		connection = nil
	end
	held = false
end

return SprintStickSystem
