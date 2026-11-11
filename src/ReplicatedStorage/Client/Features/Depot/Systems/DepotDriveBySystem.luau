--!strict
--[=[
	DepotDriveBySystem: the delivery truck that drives past the hub's yard now and then (the owner's pick L, 2026-11-11),
	so the outside feels alive. Studio places the road (parts tagged DepotSpotConstants.DRIVE_BY.TAG, `Order` 1..N) and
	the truck (one Model tagged DRIVE_BY.VEHICLE_TAG, parked out of sight at the road's start, its pivot facing
	forward). Every DepotSpotRules.driveGap seconds this client drives the truck down the road at DRIVE_BY.SPEED
	(DepotSpotRules.along) and, on some passes, honks once halfway; then it parks it back at the start. The truck is
	moved on this client only (its anchored parts' CFrames are local writes), so nothing replicates and the server
	never sees it. A place without a road or a truck does nothing.

	Spec-exempt shell (CollectionService, RunService, Sound); the road, the timing and the motion are the specced
	DepotSpotRules.

	@class DepotDriveBySystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)
local DepotSpotRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotSpotRules)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
-- Registers the horn.
require(ReplicatedStorage.Client.Features.Depot.Data.DepotAssets)

local DRIVE = DepotSpotConstants.DRIVE_BY
-- Seconds between looks for the road and the truck (they stream in with the hub).
local FIND_SECONDS = 5

local function findRoad(): { Vector3 }?
	local markers: { DepotSpotRules.RoadMarker } = {}
	for _, part in CollectionService:GetTagged(DRIVE.TAG) do
		if part:IsA("BasePart") then
			table.insert(markers, { order = part:GetAttribute(DRIVE.ORDER_ATTRIBUTE), position = part.Position })
		end
	end
	return DepotSpotRules.road(markers)
end

local function findVehicle(): Model?
	for _, model in CollectionService:GetTagged(DRIVE.VEHICLE_TAG) do
		if model:IsA("Model") then
			return model
		end
	end
	return nil
end

local function place(vehicle: Model, road: { Vector3 }, distance: number)
	local at, heading = DepotSpotRules.along(road, distance)
	local pivot = vehicle:GetPivot()
	-- Keep the truck's own height over the road points (the road parts sit on the ground).
	local ground = Vector3.new(at.X, pivot.Position.Y, at.Z)
	vehicle:PivotTo(CFrame.lookAt(ground, ground + Vector3.new(heading.X, 0, heading.Z)))
end

-- Drives one pass; returns once the truck is parked again (or the system stopped).
local function drive(vehicle: Model, road: { Vector3 }, alive: () -> boolean, rng: Random)
	local length = DepotSpotRules.roadLength(road)
	local seconds = length / DRIVE.SPEED
	local honkAt = if rng:NextNumber() < DRIVE.HORN_CHANCE then seconds * rng:NextNumber(0.35, 0.65) else math.huge
	local started = os.clock()
	while alive() do
		local t = os.clock() - started
		if t >= seconds or vehicle.Parent == nil then
			break
		end
		place(vehicle, road, t * DRIVE.SPEED)
		if t >= honkAt then
			honkAt = math.huge
			SoundServiceClient:playOneShot(DRIVE.HORN_SOUND, { at = vehicle:GetPivot().Position })
		end
		RunService.RenderStepped:Wait()
	end
	if vehicle.Parent ~= nil then
		place(vehicle, road, 0)
	end
end

local DepotDriveBySystem = {}

-- Starts the drive-bys; returns the stopper.
function DepotDriveBySystem.start(): () -> ()
	local running = true
	local function alive(): boolean
		return running
	end
	task.spawn(function()
		local rng = Random.new()
		while running do
			local road = findRoad()
			local vehicle = findVehicle()
			if road == nil or vehicle == nil then
				task.wait(FIND_SECONDS)
			else
				place(vehicle, road, 0)
				task.wait(DepotSpotRules.driveGap(rng:NextNumber()))
				if running then
					drive(vehicle, road, alive, rng)
				end
			end
		end
	end)
	return function()
		running = false
	end
end

return DepotDriveBySystem
