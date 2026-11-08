--!strict
--[=[
	EmployeeHeadLookSystem: the head look (owner note 2026-11-08; cosmetic, client-only). Every tracked employee's head
	turns a little toward where its player looks (EmployeeHeadLookFormulas.target, at most HEAD_LOOK.maxYaw either
	way and maxPitch up or down), eased, as an extra rotation on its Neck Motor6D's Transform after the frame's
	animations (RunService.PreSimulation, the slot the engine documents for overriding Motor6D.Transform), so idles and
	walks keep playing under it.

	The look is VacuumLookSystem's: the local player's own camera at once; anyone else's from the look the server
	puts on their character (VacuumMotionConstants.AIM_ATTRIBUTE / AIM_YAW_ATTRIBUTE, sent at a low rate while the
	wand is stowed). The head eases back to straight ahead and lets go while an emote or action owns it
	(EmployeeHeadLookFormulas.owned), and is left alone while the character is knocked down, ragdolled, hiding or
	dead, while the local camera is scripted (a cutscene), or beyond HEAD_LOOK.radius of the camera.

	A Neck keyed by no playing animation keeps whatever was last written to it, so the rotation is laid on the
	Transform the animations left, never on the one this wrote last frame.

	Spec-exempt shell (Motor6D, Animator, RunService); the maths is the specced EmployeeHeadLookFormulas.

	@class EmployeeHeadLookSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local EmployeeHeadLookFormulas = require(ReplicatedStorage.Client.Features.Employee.Utils.EmployeeHeadLookFormulas)
local VacuumLookSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumLookSystem)

type Head = {
	player: Player,
	model: Model,
	yaw: number,
	pitch: number,
	-- The Transform the animations left (the base) and the one this wrote on top of it, last frame.
	base: CFrame?,
	written: CFrame?,
}

export type EmployeeHeadLookState = {
	track: (player: Player, character: Model) -> () -> (),
	step: (dt: number, cameraPosition: Vector3) -> (),
	getState: () -> { tracked: number, looking: number },
}

local EmployeeHeadLookSystem = {}

local function neckOf(model: Model): Motor6D?
	local head = model:FindFirstChild("Head")
	local found = if head ~= nil then head:FindFirstChild("Neck") else nil
	return if found ~= nil and found:IsA("Motor6D") then found else nil
end

local function rootOf(model: Model): BasePart?
	local found = model:FindFirstChild("HumanoidRootPart")
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

-- Whether the character's head is somebody else's now (knocked down, ragdolled, hiding, dead, a cutscene).
local function away(head: Head): boolean
	local model = head.model
	if
		model:GetAttribute(DeathConstants.KNOCKDOWN_ATTRIBUTE) ~= nil
		or model:GetAttribute(DeathConstants.RAGDOLL_NAME) == true
		or head.player:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE) ~= nil
	then
		return true
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return true
	end
	if head.player == Players.LocalPlayer then
		local camera = Workspace.CurrentCamera
		return camera ~= nil and camera.CameraType == Enum.CameraType.Scriptable
	end
	return false
end

-- Whether an emote or action owns the head (EmployeeHeadLookFormulas.owned over the Animator's playing tracks).
local function owned(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid ~= nil then humanoid:FindFirstChildOfClass("Animator") else nil
	if animator == nil then
		return false
	end
	local tracks: { EmployeeHeadLookFormulas.TrackLike } = {}
	for _, track in animator:GetPlayingAnimationTracks() do
		table.insert(
			tracks,
			{ IsPlaying = track.IsPlaying, Priority = track.Priority, WeightCurrent = track.WeightCurrent }
		)
	end
	return EmployeeHeadLookFormulas.owned(tracks)
end

-- Lets go of `head`'s Neck: the animations' last Transform back, if this wrote over it.
local function release(head: Head, neck: Motor6D?)
	if neck ~= nil and head.written ~= nil and head.base ~= nil and neck.Transform == head.written then
		neck.Transform = head.base
	end
	head.yaw, head.pitch, head.base, head.written = 0, 0, nil, nil
end

function EmployeeHeadLookSystem.new(): EmployeeHeadLookState
	local heads: { [Model]: Head } = {}
	local looking = 0

	local function step(dt: number, cameraPosition: Vector3)
		looking = 0
		local tuning = EmployeeConstants.HEAD_LOOK
		for model, head in heads do
			local neck = neckOf(model)
			local root = rootOf(model)
			if
				not tuning.enabled
				or neck == nil
				or root == nil
				or (root.Position - cameraPosition).Magnitude > tuning.radius
				or away(head)
			then
				release(head, neck)
				continue
			end
			local wantYaw, wantPitch = 0, 0
			if not owned(model) then
				wantYaw, wantPitch = EmployeeHeadLookFormulas.target(
					VacuumLookSystem.yawOf(head.player, model, root),
					VacuumLookSystem.pitchOf(head.player, model)
				)
			end
			head.yaw = EmployeeHeadLookFormulas.ease(head.yaw, wantYaw, dt)
			head.pitch = EmployeeHeadLookFormulas.ease(head.pitch, wantPitch, dt)
			-- The animations' Transform this frame: what is there unless it is still what this wrote last frame.
			local now = neck.Transform
			local base = if head.written ~= nil and head.base ~= nil and now == head.written then head.base else now
			if math.abs(head.yaw) < 1e-4 and math.abs(head.pitch) < 1e-4 then
				release(head, neck)
				continue
			end
			local written = base * EmployeeHeadLookFormulas.transform(head.yaw, head.pitch)
			neck.Transform = written
			head.base, head.written = base, written
			looking += 1
		end
	end

	return {
		track = function(player, character)
			heads[character] = { player = player, model = character, yaw = 0, pitch = 0, base = nil, written = nil }
			return function()
				local head = heads[character]
				if head ~= nil then
					release(head, neckOf(character))
				end
				heads[character] = nil
			end
		end,
		step = step,
		getState = function()
			local tracked = 0
			for _ in heads do
				tracked += 1
			end
			return { tracked = tracked, looking = looking }
		end,
	}
end

return EmployeeHeadLookSystem
