--!strict
--[=[
	ShiftCrewStatusSystem: publishes each crew member's status four times a second while a shift runs (Cleanup Crew
	M3 UI: the crew roster's "in the truck bed" / "vacuuming", the CCTV's room, camera and rooms-from-the-truck). Reads
	Office (room, truck bed), Cargo's bed rule and Vacuum; writes public player fields through
	StateSyncPublicPlayerStore, only what changed (ShiftCrewStatusUtils). A dead player, a player who left the crew,
	and everyone once the shift stops running get their fields cleared.

	Spec-exempt shell (RunService, characters, the public store); the decisions are the specced ShiftCrewStatusUtils,
	OfficeLayoutUtils.roomAt and CargoBankRules.onBed.

	@class ShiftCrewStatusSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoBankRules = require(ReplicatedStorage.Shared.Features.Cargo.Rules.CargoBankRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)
local ShiftCrewStatusUtils = require(ServerScriptService.Features.Shift.Utils.ShiftCrewStatusUtils)
local ShiftTripSystem = require(ServerScriptService.Features.Shift.Systems.ShiftTripSystem)

type Status = ShiftCrewStatusUtils.Status

local function statusOf(player: Player): Status?
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	local bed = OfficeServiceServer:truckBed()
	local room, depth, cam = OfficeServiceServer:whereIs(root.Position)
	return {
		inTruck = bed ~= nil and CargoBankRules.onBed(bed.CFrame:PointToObjectSpace(root.Position), bed.Size),
		vacuuming = VacuumServiceServer:isVacuuming(player),
		room = room,
		roomDepth = depth,
		cam = cam,
	}
end

local ShiftCrewStatusSystem = {}

function ShiftCrewStatusSystem.start(trip: ShiftTripSystem.ShiftTripSystem, running: () -> boolean): () -> ()
	local last: { [number]: Status } = {}

	local function apply(userId: number, status: Status?)
		local change = ShiftCrewStatusUtils.changes(last[userId], status)
		if next(change.set) ~= nil then
			StateSyncPublicPlayerStore.set(userId, change.set)
		end
		for _, field in change.clear do
			StateSyncPublicPlayerStore.clearField(userId, field)
		end
		if status ~= nil then
			last[userId] = status
		else
			last[userId] = nil
		end
	end

	local function step()
		local seen: { [number]: boolean } = {}
		if running() then
			for _, player in trip:crew() do
				seen[player.UserId] = true
				apply(player.UserId, statusOf(player))
			end
		end
		for userId in last do
			if not seen[userId] then
				apply(userId, nil)
			end
		end
	end

	local elapsed = 0
	local ticking = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= ShiftConstants.CREW_STATUS_INTERVAL then
			elapsed = 0
			step()
		end
	end)
	return function()
		ticking:Disconnect()
		for userId in last do
			apply(userId, nil)
		end
	end
end

return ShiftCrewStatusSystem
