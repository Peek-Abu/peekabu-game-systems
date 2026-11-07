--!strict
--[=[
	VacuumFaceSystem: while the local player's wand is out, their body eases to face where their camera looks (vacuum
	aim fix, 2026-11-06; a soft shift-lock). Humanoid.AutoRotate is turned off and the root is turned toward the
	camera's flat heading each frame (VacuumMotionFormulas.faceToward, tuned by VacuumMotionConstants.face), bound
	just after the camera updates, as the engine's own mouse lock does. Walking then strafes and backs up instead of
	turning. The suction already aims by the body (VacuumTargetRules), so the nozzle, the camera and the suction agree.
	Off since 2026-11-07 (the owner did not want the whole body turned): VacuumMotionConstants.face.enabled = false
	leaves AutoRotate alone.

	Left alone (and AutoRotate given back) whenever the wand is stowed, the humanoid is dead, seated, platform-standing
	or not on its feet, the root is anchored, or the camera is scripted (a cutscene). Only the local player's own
	character, which this client simulates; the server's targeting and suction are untouched.

	Spec-exempt shell (RunService, Camera, Humanoid); the maths is the specced VacuumMotionFormulas.faceToward.

	@class VacuumFaceSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local Constants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)
local VacuumMotionFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumMotionFormulas)

local BIND_NAME = "VacuumFace"

-- The states a body can be turned in (on its feet or in the air).
local TURNABLE: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Landed] = true,
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
}

local bound = false
-- The humanoid whose AutoRotate this turned off (given back when it lets go).
local held: Humanoid? = nil

local VacuumFaceSystem = {}

local function letGo()
	local humanoid = held
	if humanoid ~= nil then
		humanoid.AutoRotate = true
	end
	held = nil
end

-- The local character's humanoid and root when its body should face the camera now, else nil.
local function facing(): (Humanoid?, BasePart?)
	local character = Players.LocalPlayer.Character
	if character == nil or character:FindFirstChild(VacuumConstants.TOOL_NAME) == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") or root.Anchored then
		return nil, nil
	end
	if humanoid.Health <= 0 or humanoid.Sit or humanoid.PlatformStand or not TURNABLE[humanoid:GetState()] then
		return nil, nil
	end
	return humanoid, root
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local humanoid, root = facing()
	if
		humanoid == nil
		or root == nil
		or camera == nil
		or camera.CameraType == Enum.CameraType.Scriptable
		or not Constants.face.enabled
	then
		letGo()
		return
	end
	if held ~= humanoid then
		letGo()
		held = humanoid
	end
	humanoid.AutoRotate = false
	local frame = root.CFrame
	local heading = VacuumMotionFormulas.faceToward(
		VacuumMotionFormulas.heading(frame.LookVector),
		VacuumMotionFormulas.heading(camera.CFrame.LookVector),
		dt
	)
	root.CFrame = CFrame.new(frame.Position) * CFrame.Angles(0, heading, 0)
end

function VacuumFaceSystem.start()
	if bound then
		return
	end
	bound = true
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, step)
end

function VacuumFaceSystem.stop()
	if not bound then
		return
	end
	bound = false
	RunService:UnbindFromRenderStep(BIND_NAME)
	letGo()
end

return VacuumFaceSystem
