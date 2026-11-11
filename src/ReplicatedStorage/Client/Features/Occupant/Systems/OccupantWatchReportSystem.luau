--!strict
--[=[
	OccupantWatchReportSystem: this client's camera report for a freeze kind's "watched" check (Bramble;
	OccupantWatchSystem on the server). Every FREEZE_REPORT_INTERVAL (10 Hz), and only while a freeze kind's rig (a
	model tagged OccupantConstants.TAG whose kind has the freeze twist) exists, it sends OccupantEvents.CameraReport:
	the camera's position and look direction. Nothing is sent while the monster is Harlow.

	The server trusts none of it beyond its own bounds (freshness, the camera near the head with a clear line, its own
	rays). `freezeKindOut` is specced; the rest is a RunService/ByteNet shell.

	@class OccupantWatchReportSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantEvents = require(ReplicatedStorage.Shared.Features.Occupant.Net.OccupantEvents)
local OccupantKindRegistry = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantKindRegistry)

local connection: RBXScriptConnection? = nil
local sent = 0

local OccupantWatchReportSystem = {}

--[=[
	Whether any of `rigs` (the tagged Occupant models) is a freeze kind's rig.
]=]
function OccupantWatchReportSystem.freezeKindOut(rigs: { Instance }): boolean
	for _, rig in rigs do
		if rig:IsA("Model") and OccupantKindRegistry.freezes(OccupantKindRegistry.kindOf(rig)) then
			return true
		end
	end
	return false
end

function OccupantWatchReportSystem.start()
	if connection ~= nil then
		return
	end
	local elapsed = 0
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < OccupantConstants.FREEZE_REPORT_INTERVAL then
			return
		end
		elapsed = 0
		local camera = Workspace.CurrentCamera
		if
			camera == nil
			or not OccupantWatchReportSystem.freezeKindOut(CollectionService:GetTagged(OccupantConstants.TAG))
		then
			return
		end
		local frame = camera.CFrame
		OccupantEvents.packets.CameraReport.send({ position = frame.Position, look = frame.LookVector })
		sent += 1
	end)
end

function OccupantWatchReportSystem.stop()
	local current = connection
	if current ~= nil then
		current:Disconnect()
		connection = nil
	end
end

function OccupantWatchReportSystem.getState(): { sent: number }
	return { sent = sent }
end

return OccupantWatchReportSystem
