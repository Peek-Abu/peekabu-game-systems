--!strict
--[=[
	VacuumLookSystem: where each holder looks, for the vacuum's aim layers (VacuumMotionSystem). The local player's look
	is their camera: its pitch, and its yaw left or right of their body (vacuum feel pass 2026-11-06). Both are sent to
	the server (VacuumEvents.Aim / AimYaw, quantised, at most aim.rate a second each, only on change), which puts them
	on the character for everyone else; a remote holder's look is read from there (the default third-person pitch and
	straight ahead until one arrives). Purely visual: suction targeting never reads it.

	Spec-exempt shell (Camera, ByteNet, attributes); the maths is the specced VacuumMotionFormulas.

	@class VacuumLookSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local function cameraPitch(): number
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)) else DEFAULT_LOOK
end

--[=[
	`player`'s look pitch (radians, up positive).
]=]
function VacuumLookSystem.pitchOf(player: Player, character: Model): number
	if player == Players.LocalPlayer then
		return cameraPitch()
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
		local camera = Workspace.CurrentCamera
		if camera == nil or root == nil then
			return 0
		end
		return VacuumMotionFormulas.lookHeading(
			VacuumMotionFormulas.relativeYaw(camera.CFrame.LookVector, root.CFrame.LookVector)
		)
	end
	local degrees = character:GetAttribute(Constants.AIM_YAW_ATTRIBUTE)
	return if type(degrees) == "number" then math.rad(degrees) else 0
end

--[=[
	Sends the local player's look (pitch and yaw) where it changed, at most aim.rate a second each.
]=]
function VacuumLookSystem.send(now: number, character: Model, root: BasePart?)
	local interval = 1 / Constants.aim.rate
	if now - pitchAt >= interval then
		local byte = VacuumMotionFormulas.encodeAim(cameraPitch())
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
