--!strict
--[=[
	EmployeeServiceClient: employee presentation on this client. For every employee character (an EmployeeName attribute) it
	shows the server's chosen face (EmployeeFaceSystem), drives the springy ears (EmployeeEarSystem) and the head look
	(EmployeeHeadLookSystem) once per
	frame in RunService.PreSimulation, after the frame's animations are applied, and keeps its layered clothing wrapped
	(EmployeeGarmentGuardSystem) on the same step.

	@class EmployeeServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Observers = require(ReplicatedStorage.Packages.Observers)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeEarSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeEarSystem)
local EmployeeFaceSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeFaceSystem)
local EmployeeGarmentGuardSystem =
	require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeGarmentGuardSystem)
local EmployeeHeadLookSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeHeadLookSystem)
local EmployeeLanyardSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeLanyardSystem)
local EmployeeSwapVfxSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeSwapVfxSystem)

local ears = EmployeeEarSystem.new()
local heads = EmployeeHeadLookSystem.new()
local garments = EmployeeGarmentGuardSystem.new()
local stoppers: { () -> () } = {}
local faces = 0

export type EmployeeClientState = {
	faces: number,
	ears: EmployeeEarSystem.EmployeeEarState,
	heads: { tracked: number, looking: number },
	garments: EmployeeGarmentGuardSystem.EmployeeGarmentGuardState,
}

export type EmployeeServiceClient = {
	dependencies: { string },
	start: (self: EmployeeServiceClient) -> (),
	stop: (self: EmployeeServiceClient) -> (),
	getState: (self: EmployeeServiceClient) -> EmployeeClientState,
}

local EmployeeServiceClient: EmployeeServiceClient = {
	dependencies = {},

	start = function(_self)
		table.insert(
			stoppers,
			Observers.observeCharacter(function(player: Player, character: Model)
				if character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) == nil then
					return nil
				end
				if character:GetAttribute(EmployeeConstants.SWAP_ATTRIBUTE) == true then
					EmployeeSwapVfxSystem.play(character)
				end
				faces += 1
				local releaseFace = EmployeeFaceSystem.bind(character)
				local releaseEars = ears.track(character)
				local releaseHead = heads.track(player, character)
				local releaseGarments = garments.track(character, os.clock())
				local releaseLanyard = EmployeeLanyardSystem.bind(player, character)
				return function()
					faces -= 1
					releaseFace()
					releaseEars()
					releaseHead()
					releaseGarments()
					releaseLanyard()
				end
			end)
		)
		local connection = RunService.PreSimulation:Connect(function(dt: number)
			local camera = Workspace.CurrentCamera
			if camera ~= nil then
				ears.step(dt, camera.CFrame.Position, os.clock())
				heads.step(dt, camera.CFrame.Position)
			end
			garments.step(os.clock())
		end)
		table.insert(stoppers, function()
			connection:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	getState = function(_self)
		return { faces = faces, ears = ears.getState(), heads = heads.getState(), garments = garments.getState() }
	end,
}

return EmployeeServiceClient
