--!strict
--[=[
	VacuumCameraSystem: the local player's camera while they vacuum (vacuum feel pass 2026-11-06; visual only;
	VacuumFeelFormulas decides the amounts). While they suck, the view widens a few degrees (eased, through
	CameraServiceClient:setFovOffset), and once a pile is well under way a strain shake builds (camera trauma, which
	the Shake setting scales). Each tug on the pile they suck nudges the camera; each pop they were sucking punches
	it, bigger piles harder. Other players' vacuuming never moves this camera.

	Spec-exempt shell (Camera service, RunService); the amounts are the specced VacuumFeelFormulas.

	@class VacuumCameraSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumMotionFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumMotionFormulas)
local VacuumFeelFormulas = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumFeelFormulas)
local VacuumFeedbackSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumFeedbackSystem)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)

export type Options = {
	-- Whether the local player is sucking now.
	localActive: () -> boolean,
}

local FOV_OWNER = "vacuumFeel"
local FOV_HZ, FOV_DAMPING = 2, 1
-- How far from the local nozzle a pile, a tug or a pop counts as theirs (studs).
local NEAR = 8
-- A pop within this many seconds of their last suction punches.
local POP_WINDOW = 0.6
local TUG_TRAUMA = 0.06

local connection: RBXScriptConnection? = nil
local stoppers: { () -> () } = {}
local fov = { x = 0, v = 0 }
local activeAt = -math.huge

local VacuumCameraSystem = {}

-- The local player's floor head, if they hold the vacuum.
local function nozzle(): Vector3?
	local character = Players.LocalPlayer.Character
	local tool = if character ~= nil then character:FindFirstChild(VacuumConstants.TOOL_NAME) else nil
	local head = if tool ~= nil then tool:FindFirstChild(VacuumConstants.FLOOR_HEAD_NAME) else nil
	return if head ~= nil and head:IsA("BasePart") then head.Position else nil
end

local function near(position: Vector3): boolean
	local point = nozzle()
	return point ~= nil and (point - position).Magnitude <= NEAR
end

function VacuumCameraSystem.start(options: Options)
	if connection ~= nil then
		return
	end
	connection = RunService.RenderStepped:Connect(function(dt: number)
		local step = math.min(dt, 0.1)
		local point = nozzle()
		local active = options.localActive() and point ~= nil
		local progress = if active and point ~= nil then VacuumFeedbackSystem.progressNear(point, NEAR) or 0 else 0
		if active then
			activeAt = os.clock()
		end
		fov.x, fov.v =
			VacuumMotionFormulas.step(fov.x, fov.v, VacuumFeelFormulas.fov(active, progress), step, FOV_HZ, FOV_DAMPING)
		CameraServiceClient:setFovOffset(FOV_OWNER, if math.abs(fov.x) < 0.01 then 0 else fov.x)
		local strain = VacuumFeelFormulas.strain(progress)
		if strain > 0 then
			CameraServiceClient:addTrauma(strain * step)
		end
	end)
	table.insert(
		stoppers,
		VacuumFeedbackSystem.onPop(function(position: Vector3, size: number)
			if os.clock() - activeAt <= POP_WINDOW and near(position) then
				CameraServiceClient:addTrauma(VacuumFeelFormulas.popTrauma(size))
			end
		end)
	)
	table.insert(
		stoppers,
		VacuumFeedbackSystem.onTug(function(position: Vector3)
			if os.clock() - activeAt <= POP_WINDOW and near(position) then
				CameraServiceClient:addTrauma(TUG_TRAUMA)
			end
		end)
	)
end

function VacuumCameraSystem.stop()
	local current = connection
	if current ~= nil then
		current:Disconnect()
	end
	connection = nil
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	fov.x, fov.v = 0, 0
	CameraServiceClient:setFovOffset(FOV_OWNER, 0)
end

return VacuumCameraSystem
