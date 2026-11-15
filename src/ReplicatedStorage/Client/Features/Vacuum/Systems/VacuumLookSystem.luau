--!strict
--[=[
	VacuumLookSystem: where each holder looks, for the vacuum's aim layers (VacuumMotionSystem). The local player's look
	is a pitch and a yaw left or right of their body (vacuum feel pass 2026-11-06). With a mouse (P1 2026-11-14: the
	nozzle follows the mouse) it is the ray through the cursor (VacuumMotionFormulas.pointerLook): its pitch, and where
	it meets the floor seen from the body; on touch, a gamepad, or with the mouse locked to the centre (Shift Lock,
	first person) it is the camera's look, which those players steer. Both are sent to the server (VacuumEvents.Aim /
	AimYaw, quantised, at most aim.rate a second each, only on change), which puts them on the character for everyone
	else and lays the suction's nozzle from them; a remote holder's look is read from there (the default third-person
	pitch and straight ahead until one arrives).

	Spec-exempt shell (Camera, UserInputService, ByteNet, attributes); the maths is the specced VacuumMotionFormulas.

	@class VacuumLookSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)
local VacuumEvents = require(ReplicatedStorage.Shared.Features.Vacuum.Net.VacuumEvents)
local VacuumMotionFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumMotionFormulas)

-- A remote holder who has sent no aim yet looks the default third-person way.
local DEFAULT_LOOK = math.rad(-20)

local lastPitch: number? = nil
local lastYaw: number? = nil
local pitchAt = -math.huge
local yawAt = -math.huge
local sent = 0

local VacuumLookSystem = {}

-- The last input came from a mouse or a keyboard (not touch or a gamepad).
local POINTER_INPUTS: { [Enum.UserInputType]: true } = {
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseButton3] = true,
	[Enum.UserInputType.MouseWheel] = true,
	[Enum.UserInputType.Keyboard] = true,
}

-- Whether the local look follows the mouse cursor: a mouse is the player's input and the cursor moves freely.
local function followsPointer(): boolean
	return UserInputService.MouseEnabled
		and UserInputService.MouseBehavior == Enum.MouseBehavior.Default
		and POINTER_INPUTS[UserInputService:GetLastInputType()] == true
end

-- The local player's look: its pitch and its yaw off the body (radians), before lookHeading.
local function localLook(character: Model, root: BasePart?): (number, number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return DEFAULT_LOOK, 0
	end
	local look = camera.CFrame.LookVector
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root ~= nil and humanoid ~= nil and followsPointer() then
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local floorY = root.Position.Y - (root.Size.Y / 2 + humanoid.HipHeight)
		return VacuumMotionFormulas.pointerLook(ray.Origin, ray.Direction, root.CFrame, floorY)
	end
	local pitch = math.asin(math.clamp(look.Y, -1, 1))
	return pitch, if root ~= nil then VacuumMotionFormulas.relativeYaw(look, root.CFrame.LookVector) else 0
end

--[=[
	`player`'s look pitch (radians, up positive).
]=]
function VacuumLookSystem.pitchOf(player: Player, character: Model): number
	if player == Players.LocalPlayer then
		local root = character:FindFirstChild("HumanoidRootPart")
		local pitch = localLook(character, if root ~= nil and root:IsA("BasePart") then root else nil)
		return pitch
	end
	local degrees = character:GetAttribute(Constants.AIM_ATTRIBUTE)
	return if type(degrees) == "number" then math.rad(degrees) else DEFAULT_LOOK
end

--[=[
	Where `player` looks left or right of their body (radians, left positive), as the wand aims at it
	(VacuumMotionFormulas.lookHeading; the local player's is sent so, so every client sees the same).
]=]
function VacuumLookSystem.yawOf(player: Player, character: Model, root: BasePart?): number
	if player == Players.LocalPlayer then
		if root == nil then
			return 0
		end
		local _, yaw = localLook(character, root)
		return VacuumMotionFormulas.lookHeading(yaw)
	end
	local degrees = character:GetAttribute(Constants.AIM_YAW_ATTRIBUTE)
	return if type(degrees) == "number" then math.rad(degrees) else 0
end

--[=[
	Sends the local player's look (pitch and yaw) where it changed, at most aim.rate a second each while the wand is
	`holding` out, else at most aim.idleRate (the head look, EmployeeHeadLookSystem, reads it on every character).
]=]
function VacuumLookSystem.send(now: number, character: Model, root: BasePart?, holding: boolean)
	local interval = 1 / (if holding then Constants.aim.rate else Constants.aim.idleRate)
	if now - pitchAt >= interval then
		local byte = VacuumMotionFormulas.encodeAim(VacuumLookSystem.pitchOf(Players.LocalPlayer, character))
		if byte ~= lastPitch then
			lastPitch, pitchAt = byte, now
			sent += 1
			VacuumEvents.packets.Aim.send(byte)
		end
	end
	if now - yawAt >= interval then
		local byte = VacuumMotionFormulas.encodeYaw(VacuumLookSystem.yawOf(Players.LocalPlayer, character, root))
		if byte ~= lastYaw then
			lastYaw, yawAt = byte, now
			sent += 1
			VacuumEvents.packets.AimYaw.send(byte)
		end
	end
end

function VacuumLookSystem.reset()
	lastPitch, lastYaw = nil, nil
end

function VacuumLookSystem.sentCount(): number
	return sent
end

return VacuumLookSystem
