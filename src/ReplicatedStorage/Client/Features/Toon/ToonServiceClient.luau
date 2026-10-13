--!strict
--[=[
	ToonServiceClient: toon presentation on this client. For every toon character (a ToonName attribute) it
	shows the server's chosen face (ToonFaceSystem) and drives the springy ears (ToonEarSystem) once per
	frame in RunService.PreSimulation, after the frame's animations are applied.

	@class ToonServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Observers = require(ReplicatedStorage.Packages.Observers)
local ToonConstants = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonConstants)
local ToonEarSystem = require(ReplicatedStorage.Client.Features.Toon.Systems.ToonEarSystem)
local ToonFaceSystem = require(ReplicatedStorage.Client.Features.Toon.Systems.ToonFaceSystem)

local ears = ToonEarSystem.new()
local stoppers: { () -> () } = {}
local faces = 0

export type ToonClientState = {
	faces: number,
	ears: ToonEarSystem.ToonEarState,
}

export type ToonServiceClient = {
	dependencies: { string },
	start: (self: ToonServiceClient) -> (),
	stop: (self: ToonServiceClient) -> (),
	getState: (self: ToonServiceClient) -> ToonClientState,
}

local ToonServiceClient: ToonServiceClient = {
	dependencies = {},

	start = function(_self)
		table.insert(
			stoppers,
			Observers.observeCharacter(function(_player: Player, character: Model)
				if character:GetAttribute(ToonConstants.NAME_ATTRIBUTE) == nil then
					return nil
				end
				faces += 1
				local releaseFace = ToonFaceSystem.bind(character)
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

return ToonServiceClient
