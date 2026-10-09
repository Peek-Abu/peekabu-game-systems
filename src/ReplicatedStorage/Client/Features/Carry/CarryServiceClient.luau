--!strict
--[=[
	CarryServiceClient: the `drop` and `throw` Input actions. While the local player carries something
	(their public `carrying` field), pressing them sends one request to the server, which decides.

	Spec-exempt shell (Input, Camera, ByteNet); the rules are on the server.

	@class CarryServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CarryShared = ReplicatedStorage.Shared.Features.Carry
local CarryConstants = require(CarryShared.Data.CarryConstants)
local CarryEvents = require(CarryShared.Net.CarryEvents)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

local unbinders: { () -> () } = {}

local function isCarrying(): boolean
	local entry = StateSyncClientStore.publicPlayers()[StateSyncConstants.publicEntryKey(Players.LocalPlayer.UserId)]
	return entry ~= nil and entry[CarryConstants.PUBLIC_FIELD] ~= nil
end

export type CarryServiceClient = {
	dependencies: { string },
	init: (self: CarryServiceClient) -> (),
	start: (self: CarryServiceClient) -> (),
	stop: (self: CarryServiceClient) -> (),
	isCarrying: (self: CarryServiceClient) -> boolean,
}

local CarryServiceClient: CarryServiceClient = {
	dependencies = { "InputServiceClient" },

	--[=[
		Registers the drop / throw actions (a game may register its own bindings first).
	]=]
	init = function(_self)
		if not InputActionRegistry.has("drop") then
			InputActionRegistry.register("drop", {
				context = "gameplay",
				bindings = { keyboard = { Enum.KeyCode.G }, gamepad = { Enum.KeyCode.DPadDown } },
				description = "Drop what you are carrying",
			})
		end
		if not InputActionRegistry.has("throw") then
			InputActionRegistry.register("throw", {
				context = "gameplay",
				bindings = { keyboard = { Enum.KeyCode.F }, gamepad = { Enum.KeyCode.ButtonR1 } },
				description = "Throw what you are carrying",
			})
		end
	end,

	start = function(_self)
		table.insert(
			unbinders,
			InputServiceClient:bind("drop", function(phase)
				if phase == "begin" and isCarrying() then
					CarryEvents.packets.Drop.send(true)
				end
			end)
		)
		table.insert(
			unbinders,
			InputServiceClient:bind("throw", function(phase)
				local camera = Workspace.CurrentCamera
				if phase == "begin" and camera ~= nil and isCarrying() then
					CarryEvents.packets.Throw.send(camera.CFrame.LookVector)
				end
			end)
		)
	end,

	stop = function(_self)
		for _, unbind in unbinders do
			unbind()
		end
		table.clear(unbinders)
	end,

	isCarrying = function(_self)
		return isCarrying()
	end,
}

return CarryServiceClient
