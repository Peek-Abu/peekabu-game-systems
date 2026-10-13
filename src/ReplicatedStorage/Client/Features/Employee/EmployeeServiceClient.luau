--!strict
--[=[
	EmployeeServiceClient: employee presentation on this client. For every employee character (an EmployeeName attribute) it
	shows the server's chosen face (EmployeeFaceSystem) and drives the springy ears (EmployeeEarSystem) once per
	frame in RunService.PreSimulation, after the frame's animations are applied.

	@class EmployeeServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Observers = require(ReplicatedStorage.Packages.Observers)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeEarSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeEarSystem)
local EmployeeFaceSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeFaceSystem)

local ears = EmployeeEarSystem.new()
local stoppers: { () -> () } = {}
local faces = 0

export type EmployeeClientState = {
	faces: number,
	ears: EmployeeEarSystem.EmployeeEarState,
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
			Observers.observeCharacter(function(_player: Player, character: Model)
				if character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) == nil then
					return nil
				end
				faces += 1
				local releaseFace = EmployeeFaceSystem.bind(character)
				local releaseEars = ears.track(character)
				return function()
					faces -= 1
					releaseFace()
					releaseEars()
				end
			end)
		)
		local connection = RunService.PreSimulation:Connect(function(dt: number)
			local camera = Workspace.CurrentCamera
			if camera ~= nil then
				ears.step(dt, camera.CFrame.Position, os.clock())
			end
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
		return { faces = faces, ears = ears.getState() }
	end,
}

return EmployeeServiceClient
